# frozen_string_literal: true

class UploadedFile < ApplicationRecord
  # ActiveStorage attachment
  has_one_attached :file

  # Polymorphic association
  belongs_to :uploadable, polymorphic: true, optional: true

  # Validations
  validates :name, presence: true
  validates :file_type, presence: true, inclusion: { 
    in: %w[log screenshot config metrics_import other] 
  }
  validate :acceptable_file

  # Scopes
  scope :by_type, ->(type) { where(file_type: type) if type.present? }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :orphaned, -> { where(uploadable_id: nil) }

  # Callbacks
  before_validation :set_name_from_file, on: :create

  # Методы
  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true)
  end

  def download_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_path(file, disposition: 'attachment', only_path: true)
  end

  def file_size
    return nil unless file.attached?
    file.byte_size
  end

  def file_size_human
    return nil unless file.attached?
    ActionController::Base.helpers.number_to_human_size(file.byte_size)
  end

  def content_type
    return nil unless file.attached?
    file.content_type
  end

  def image?
    content_type&.start_with?('image/')
  end

  def text?
    content_type&.start_with?('text/') || 
      %w[application/json application/xml].include?(content_type)
  end

  private

  def set_name_from_file
    return if name.present? || !file.attached?
    self.name = file.filename.to_s
  end

  def acceptable_file
    return unless file.attached?

    # Максимальный размер 50MB
    if file.byte_size > 50.megabytes
      errors.add(:file, I18n.t('errors.file_too_large', max_size: '50MB'))
    end

    # Разрешённые типы файлов
    acceptable_types = [
      'image/png', 'image/jpeg', 'image/gif', 'image/webp',
      'text/plain', 'text/csv', 'text/log',
      'application/json', 'application/xml',
      'application/pdf',
      'application/zip', 'application/gzip',
      'application/octet-stream'
    ]

    unless acceptable_types.include?(file.content_type)
      errors.add(:file, I18n.t('errors.unacceptable_file_type'))
    end
  end
end
