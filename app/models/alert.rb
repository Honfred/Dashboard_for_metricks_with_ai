class Alert < ApplicationRecord
  # ActiveStorage attachments
  has_many_attached :screenshots  # Скриншоты ошибок
  has_many_attached :logs         # Логи для анализа
  
  # Polymorphic attachments
  has_many :uploaded_files, as: :uploadable, dependent: :destroy

  # Валидации
  validates :service, :metric, :value, :threshold, :severity, presence: true
  validates :status, presence: true, inclusion: { in: %w(triggered resolved acknowledged) }
  validates :severity, inclusion: { in: %w(info warning critical) }
  
  # Скоупы для фильтрации
  scope :active, -> { where(status: 'triggered') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :by_severity, ->(severity) { where(severity: severity) if severity.present? }
  scope :by_service, ->(service) { where(service: service) if service.present? }
  scope :recent, -> { order(triggered_at: :desc) }
  
  # Методы
  def active?
    status == 'triggered'
  end
  
  def resolved?
    status == 'resolved'
  end
  
  def acknowledged?
    status == 'acknowledged'
  end
  
  def resolve!
    update(status: 'resolved', resolved_at: Time.current)
  end
  
  def acknowledge!
    update(status: 'acknowledged')
  end
  
  def trigger!
    return if active?
    update(status: 'triggered', triggered_at: Time.current, resolved_at: nil)
  end
  
  # Фабричный метод для создания оповещения
  def self.trigger_for(service, metric, value, threshold, severity = 'warning', message = nil)
    # Проверяем, не существует ли уже активное оповещение для этого сервиса и метрики
    alert = Alert.find_by(service: service, metric: metric, status: 'triggered')
    
    if alert
      # Обновляем существующее оповещение
      alert.update(
        value: value,
        threshold: threshold,
        severity: severity,
        message: message || default_message(service, metric, value, threshold),
        triggered_at: Time.current
      )
      return alert
    end
    
    # Создаем новое оповещение
    Alert.create(
      service: service,
      metric: metric,
      value: value,
      threshold: threshold,
      severity: severity,
      status: 'triggered',
      message: message || default_message(service, metric, value, threshold),
      triggered_at: Time.current
    )
  end
  
  private
  
  # Формирование сообщения по умолчанию
  def self.default_message(service, metric, value, threshold)
    "#{service}: метрика #{metric} превысила пороговое значение #{threshold} и достигла #{value}"
  end
end
