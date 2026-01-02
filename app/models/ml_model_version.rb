# frozen_string_literal: true

class MlModelVersion < ApplicationRecord
  # ActiveStorage attachment для файла модели
  has_one_attached :model_file, service: :ml_models
  has_one_attached :training_log, service: :ml_models

  # Callbacks - должны быть перед валидациями для генерации version
  before_validation :set_version, on: :create

  # Validations
  validates :model_type, presence: true, inclusion: { 
    in: %w[anomaly performance trend] 
  }
  validates :version, presence: true
  validates :status, presence: true, inclusion: { 
    in: %w[training completed failed deployed deprecated] 
  }
  validates :version, uniqueness: { scope: :model_type }

  # Scopes
  scope :by_type, ->(type) { where(model_type: type) if type.present? }
  scope :active, -> { where(is_active: true) }
  scope :completed, -> { where(status: 'completed') }
  scope :deployed, -> { where(status: 'deployed') }
  scope :recent, -> { order(created_at: :desc) }

  # Class methods
  def self.active_model(model_type)
    by_type(model_type).active.first
  end

  def self.latest_model(model_type)
    by_type(model_type).completed.recent.first
  end

  # Статус методы
  def training?
    status == 'training'
  end

  def completed?
    status == 'completed'
  end

  def deployed?
    status == 'deployed'
  end

  def failed?
    status == 'failed'
  end

  def deprecated?
    status == 'deprecated'
  end

  # Методы работы с моделью
  def mark_completed!(accuracy: nil, f1_score: nil, **other_metrics)
    self.metrics = metrics.merge(
      accuracy: accuracy,
      f1_score: f1_score,
      **other_metrics
    ).compact
    self.trained_at = Time.current
    self.status = 'completed'
    save!
  end

  def mark_failed!(error_message = nil)
    self.metadata['error'] = error_message if error_message
    self.status = 'failed'
    save!
  end

  def deploy!
    transaction do
      # Деактивировать текущую активную модель этого типа
      self.class.by_type(model_type).active.update_all(is_active: false, status: 'deprecated')
      
      # Активировать эту модель
      update!(
        is_active: true,
        status: 'deployed',
        deployed_at: Time.current
      )
    end
  end

  def model_file_url
    return nil unless model_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(model_file, only_path: true)
  end

  def accuracy
    metrics['accuracy']
  end

  def f1_score
    metrics['f1_score']
  end

  # Получить имя метрики из metadata
  def metric_name
    metadata['metric_name']
  end

  # Человекочитаемое название
  def display_name
    if metric_name.present?
      "#{metric_name} (#{model_type})"
    else
      "#{model_type} v#{version}"
    end
  end

  private

  def set_version
    return if version.present?
    
    last_version = self.class.by_type(model_type).maximum(:version)
    if last_version.present?
      major, minor = last_version.split('.').map(&:to_i)
      self.version = "#{major}.#{minor + 1}"
    else
      self.version = '1.0'
    end
  end
end
