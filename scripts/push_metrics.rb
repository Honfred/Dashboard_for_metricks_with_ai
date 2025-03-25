#!/usr/bin/env ruby
require 'net/http'
require 'uri'

# Конфигурация
PUSHGATEWAY_URL = 'http://localhost:9091/metrics/job/custom_metrics'
METRICS = [
  {
    name: 'rails_requests_total',
    type: 'counter',
    help: 'Total number of requests processed by the Rails application',
    value: 2345,
    labels: { status: '200', endpoint: '/api/v1/data' }
  },
  {
    name: 'rails_request_duration_seconds',
    type: 'histogram',
    help: 'Request duration histogram in seconds',
    value: 0.456,
    labels: { status: '200', endpoint: '/api/v1/data' }
  },
  {
    name: 'rails_memory_usage_bytes',
    type: 'gauge',
    help: 'Memory usage of the Rails application in bytes',
    value: 234567890,
    labels: { instance: 'web:3000' }
  },
  {
    name: 'rails_active_record_connections',
    type: 'gauge',
    help: 'Number of active database connections',
    value: 5,
    labels: { pool: 'primary' }
  },
  {
    name: 'demo_cpu_usage_percent',
    type: 'gauge',
    help: 'Demo CPU usage percentage',
    value: 45.2,
    labels: { core: 'all' }
  },
  {
    name: 'demo_api_requests_total',
    type: 'counter',
    help: 'Demo total API requests',
    value: 1500,
    labels: { endpoint: '/api/metrics', status: 'success' }
  }
]

# Формирование данных в формате, который понимает Pushgateway
def generate_metrics_data
  output = []
  
  METRICS.each do |metric|
    # Добавляем HELP комментарий (описание метрики)
    output << "# HELP #{metric[:name]} #{metric[:help]}"
    # Добавляем TYPE комментарий (тип метрики)
    output << "# TYPE #{metric[:name]} #{metric[:type]}"
    
    # Формируем строку с метками (если они есть)
    labels_str = ""
    if metric[:labels] && !metric[:labels].empty?
      labels_parts = metric[:labels].map { |k, v| "#{k}=\"#{v}\"" }
      labels_str = "{#{labels_parts.join(', ')}}"
    end
    
    # Добавляем значение метрики
    output << "#{metric[:name]}#{labels_str} #{metric[:value]}"
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
  
  if response.code.to_i >= 200 && response.code.to_i < 300
    puts "Metrics successfully pushed to gateway!"
  else
    puts "Failed to push metrics. Response: #{response.code} #{response.message}"
    puts response.body
  end
end

# Выполняем отправку
push_to_gateway 