#!/usr/bin/env ruby
require 'net/http'
require 'uri'

# Конфигурация
PUSHGATEWAY_URL = 'http://localhost:9091/metrics/job/app_metrics'
# Метрики, которые ожидает приложение
METRICS = [
  {
    name: 'http_request_duration_seconds',
    type: 'histogram',
    help: 'HTTP request duration in seconds',
    value: 0.345,
    labels: { method: 'GET', path: '/api/data' }
  },
  {
    name: 'http_requests_total',
    type: 'counter',
    help: 'Total number of HTTP requests',
    value: 1234,
    labels: { method: 'GET', path: '/api/data', status: '200' }
  },
  {
    name: 'http_requests_total',
    type: 'counter',
    help: 'Total number of HTTP requests',
    value: 456,
    labels: { method: 'POST', path: '/api/data', status: '200' }
  },
  {
    name: 'http_requests_errors_total',
    type: 'counter',
    help: 'Total number of HTTP request errors',
    value: 78,
    labels: { method: 'GET', path: '/api/data', status: '500' }
  },
  {
    name: 'process_cpu_seconds_total',
    type: 'gauge',
    help: 'Total user and system CPU time spent in seconds',
    value: 123.45,
    labels: { service: 'web' }
  },
  {
    name: 'process_resident_memory_bytes',
    type: 'gauge',
    help: 'Resident memory size in bytes',
    value: 256000000,
    labels: { service: 'web' }
  },
  {
    name: 'sidekiq_job_duration_seconds',
    type: 'histogram',
    help: 'Duration of Sidekiq job execution in seconds',
    value: 0.56,
    labels: { queue: 'default', class: 'EmailJob' }
  },
  {
    name: 'up',
    type: 'gauge',
    help: 'Whether the service is up or not',
    value: 1,
    labels: { service: 'web' }
  },
  {
    name: 'up',
    type: 'gauge',
    help: 'Whether the service is up or not',
    value: 1,
    labels: { service: 'sidekiq' }
  }
]

# Формирование данных в формате, который понимает Pushgateway
def generate_metrics_data
  output = []
  
  # Группируем метрики по имени
  metrics_by_name = {}
  METRICS.each do |metric|
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
    # Добавляем HELP комментарий (описание метрики) только один раз для каждого имени
    output << "# HELP #{name} #{data[:help]}"
    # Добавляем TYPE комментарий (тип метрики) только один раз для каждого имени
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
  
  if response.code.to_i >= 200 && response.code.to_i < 300
    puts "Metrics successfully pushed to gateway!"
  else
    puts "Failed to push metrics. Response: #{response.code} #{response.message}"
    puts response.body
  end
end

# Выполняем отправку
push_to_gateway 