# frozen_string_literal: true

class Report < ApplicationRecord
  # ActiveStorage attachment для файла отчёта
  has_one_attached :file, service: :reports

  # Validations
  validates :name, presence: true
  validates :report_type, presence: true, inclusion: { 
    in: %w[metrics alerts ai_analysis dashboard combined] 
  }
  validates :format, presence: true, inclusion: { in: %w[pdf csv json] }
  validates :status, presence: true, inclusion: { 
    in: %w[pending processing completed failed] 
  }

  # Scopes
  scope :completed, -> { where(status: 'completed') }
  scope :pending, -> { where(status: 'pending') }
  scope :by_type, ->(type) { where(report_type: type) if type.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }

  # Callbacks
  after_create :schedule_generation

  # Методы статуса
  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  # Методы для работы с файлом
  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true)
  end

  def file_size
    return nil unless file.attached?
    file.byte_size
  end

  def file_size_human
    return nil unless file.attached?
    number_to_human_size(file.byte_size)
  end

  # Статус методы
  def mark_processing!
    update!(status: 'processing')
  end

  def mark_completed!
    update!(status: 'completed', generated_at: Time.current)
  end

  def mark_failed!(error_message = nil)
    metadata['error'] = error_message if error_message
    update!(status: 'failed', metadata: metadata)
  end

  private

  def schedule_generation
    ReportGenerationJob.perform_later(id)
  end

  include ActionView::Helpers::NumberHelper
end
