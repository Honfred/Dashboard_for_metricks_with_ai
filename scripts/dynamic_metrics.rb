#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'

# Конфигурация
PUSHGATEWAY_URL = 'http://localhost:9091/metrics/job/dynamic_metrics'
INTERVAL = 10 # секунд между отправками

# Начальные значения для метрик
@counters = {
  'rails_requests_total' => 0,
  'demo_api_requests_total' => 0
}

# Функция для генерации значений метрик с реалистичными изменениями
def generate_metrics_values
  # Генерируем реалистичные данные на основе времени
  time = Time.now
  hour_of_day = time.hour
  
  # Используем время суток для создания более реалистичного паттерна
  time_factor = (Math.sin(hour_of_day / 24.0 * 2 * Math::PI) + 1) / 2.0
  
  # Увеличиваем значения счетчиков
  @counters['rails_requests_total'] += rand(10..50)
  @counters['demo_api_requests_total'] += rand(5..30)
  
  # Формируем массив с данными метрик
  [
    {
      name: 'rails_requests_total',
      type: 'counter',
      help: 'Total number of requests processed by the Rails application',
      value: @counters['rails_requests_total'],
      labels: { status: '200', endpoint: '/api/v1/data' }
    },
    {
      name: 'rails_requests_total',
      type: 'counter',
      help: 'Total number of requests processed by the Rails application',
      value: (@counters['rails_requests_total'] * 0.2).to_i,
      labels: { status: '404', endpoint: '/api/v1/missing' }
    },
    {
      name: 'rails_request_duration_seconds',
      type: 'histogram',
      help: 'Request duration histogram in seconds',
      value: (0.2 + rand() * 0.5 * time_factor).round(3),
      labels: { status: '200', endpoint: '/api/v1/data' }
    },
    {
      name: 'rails_memory_usage_bytes',
      type: 'gauge',
      help: 'Memory usage of the Rails application in bytes',
      value: (200_000_000 + rand(100_000_000) * time_factor).to_i,
      labels: { instance: 'web:3000' }
    },
    {
      name: 'rails_active_record_connections',
      type: 'gauge',
      help: 'Number of active database connections',
      value: (3 + rand(5) * time_factor).to_i,
      labels: { pool: 'primary' }
    },
    {
      name: 'demo_cpu_usage_percent',
      type: 'gauge',
      help: 'Demo CPU usage percentage',
      value: (20 + 40 * time_factor + rand(-10..10)).round(1),
      labels: { core: 'all' }
    },
    {
      name: 'demo_api_requests_total',
      type: 'counter',
      help: 'Demo total API requests',
      value: @counters['demo_api_requests_total'],
      labels: { endpoint: '/api/metrics', status: 'success' }
    },
    {
      name: 'demo_api_requests_total',
      type: 'counter',
      help: 'Demo total API requests',
      value: (@counters['demo_api_requests_total'] * 0.1).to_i,
      labels: { endpoint: '/api/metrics', status: 'error' }
    }
  ]
end

# Формирование данных в формате, который понимает Pushgateway
def generate_metrics_data
  metrics = generate_metrics_values
  output = []
  
  # Группируем метрики по имени для правильного форматирования HELP и TYPE
  metrics_by_name = {}
  metrics.each do |metric|
    metrics_by_name[metric[:name]] ||= {
      type: metric[:type],
      help: metric[:help],
      values: []
    }
    metrics_by_name[metric[:name]][:values] << {
      labels: metric[:labels],
      value: metric[:value]
    }
  end
  
  # Формируем вывод в формате Prometheus
  metrics_by_name.each do |name, data|
    # Добавляем HELP комментарий (описание метрики)
    output << "# HELP #{name} #{data[:help]}"
    # Добавляем TYPE комментарий (тип метрики)
    output << "# TYPE #{name} #{data[:type]}"
    
    # Добавляем значения с метками
    data[:values].each do |value_info|
      # Формируем строку с метками
      labels_str = ""
      if value_info[:labels] && !value_info[:labels].empty?
        labels_parts = value_info[:labels].map { |k, v| "#{k}=\"#{v}\"" }
        labels_str = "{#{labels_parts.join(', ')}}"
      end
      
      # Добавляем значение метрики
      output << "#{name}#{labels_str} #{value_info[:value]}"
    end
    
    # Добавляем пустую строку для лучшей читаемости
    output << ""
  end
  
  output.join("\n")
end

# Отправляем данные в Pushgateway
def push_to_gateway
  uri = URI.parse(PUSHGATEWAY_URL)
  request = Net::HTTP::Post.new(uri)
  request.body = generate_metrics_data
  request["Content-Type"] = "text/plain"
  
  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end
  
  time = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  if response.code.to_i >= 200 && response.code.to_i < 300
    puts "[#{time}] Metrics successfully pushed to gateway!"
  else
    puts "[#{time}] Failed to push metrics. Response: #{response.code} #{response.message}"
    puts response.body
  end
end

# Главный цикл для периодической отправки метрик
puts "Starting dynamic metrics generation (Ctrl+C to stop)..."
loop do
  push_to_gateway
  sleep INTERVAL
end 