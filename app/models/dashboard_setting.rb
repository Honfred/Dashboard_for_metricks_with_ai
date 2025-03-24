class DashboardSetting < ApplicationRecord
  serialize :settings, coder: JSON

  validates :name, presence: true
  validates :name, uniqueness: true
  
  # Настройки дашборда по умолчанию
  def self.default_settings
    {
      refresh_interval: '30s',
      time_range: '1h',
      displayed_panels: ['service-health', 'response-time', 'throughput', 'error-rate', 'resource-usage'],
      layout: {
        rows: [
          { panels: ['service-health'] },
          { panels: ['response-time', 'throughput'] },
          { panels: ['error-rate', 'resource-usage'] }
        ]
      }
    }
  end
  
  # Получение настроек с применением значений по умолчанию
  def merged_settings
    self.class.default_settings.deep_merge(settings || {})
  end
  
  # Получение текущих настроек или создание по умолчанию
  def self.current(name = 'default')
    find_by(name: name) || create(name: name, settings: default_settings)
  end
end 