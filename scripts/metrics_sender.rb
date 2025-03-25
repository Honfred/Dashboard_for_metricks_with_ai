#!/usr/bin/env ruby
require 'net/http'
require 'uri'

# Данные для каждой метрики
metrics_data = [
  {
    name: 'http_request_duration_seconds',
    type: 'histogram',
    help: 'HTTP request duration in seconds',
    data: [
      { labels: { method: 'GET', path: '/api/data' }, value: 0.345 },
      { labels: { method: 'POST', path: '/api/data' }, value: 0.567 },
      { labels: { method: 'GET', path: '/api/users' }, value: 0.123 }
    ]
  },
  {
    name: 'http_requests_total',
    type: 'counter',
    help: 'Total number of HTTP requests',
    data: [
      { labels: { method: 'GET', path: '/api/data', status: '200' }, value: 1234 },
      { labels: { method: 'POST', path: '/api/data', status: '200' }, value: 456 },
      { labels: { method: 'GET', path: '/api/users', status: '200' }, value: 789 }
    ]
  },
  {
    name: 'http_requests_errors_total',
    type: 'counter',
    help: 'Total number of HTTP request errors',
    data: [
      { labels: { method: 'GET', path: '/api/data', status: '500' }, value: 78 },
      { labels: { method: 'POST', path: '/api/data', status: '422' }, value: 45 },
      { labels: { method: 'GET', path: '/api/users', status: '404' }, value: 123 }
    ]
  },
  {
    name: 'process_cpu_seconds_total',
    type: 'gauge',
    help: 'Total user and system CPU time spent in seconds',
    data: [
      { labels: { service: 'web' }, value: 123.45 },
      { labels: { service: 'sidekiq' }, value: 67.89 }
    ]
  },
  {
    name: 'process_resident_memory_bytes',
    type: 'gauge',
    help: 'Resident memory size in bytes',
    data: [
      { labels: { service: 'web' }, value: 256000000 },
      { labels: { service: 'sidekiq' }, value: 128000000 }
    ]
  },
  {
    name: 'sidekiq_job_duration_seconds',
    type: 'histogram',
    help: 'Duration of Sidekiq job execution in seconds',
    data: [
      { labels: { queue: 'default', class: 'EmailJob' }, value: 0.56 },
      { labels: { queue: 'high', class: 'NotificationJob' }, value: 0.78 },
      { labels: { queue: 'low', class: 'ReportJob' }, value: 1.23 }
    ]
  },
  {
    name: 'up',
    type: 'gauge',
    help: 'Whether the service is up or not',
    data: [
      { labels: { service: 'web' }, value: 1 },
      { labels: { service: 'sidekiq' }, value: 1 },
      { labels: { service: 'database' }, value: 1 }
    ]
  }
]

# Отправка метрик в Pushgateway
def send_metric_to_pushgateway(metric_name, metric_type, metric_help, metric_data)
  # Формируем метрику в текстовом формате Prometheus
  metric_text = "# HELP #{metric_name} #{metric_help}\n"
  metric_text += "# TYPE #{metric_name} #{metric_type}\n"
  
  metric_data.each do |data|
    # Форматируем метки
    labels_str = data[:labels].map { |k, v| "#{k}=\"#{v}\"" }.join(',')
    metric_text += "#{metric_name}{#{labels_str}} #{data[:value]}\n"
  end
  
  # Отправляем в Pushgateway
  uri = URI.parse("http://localhost:9091/metrics/job/app_metrics")
  request = Net::HTTP::Post.new(uri)
  request.body = metric_text
  request["Content-Type"] = "text/plain"
  
  begin
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
    
    if response.code.to_i >= 200 && response.code.to_i < 300
      puts "Метрика #{metric_name} успешно отправлена"
      return true
    else
      puts "Ошибка при отправке метрики #{metric_name}: #{response.code} #{response.message}"
      return false
    end
  rescue => e
    puts "Исключение при отправке метрики #{metric_name}: #{e.message}"
    return false
  end
end

# Отправляем каждую метрику
puts "Начинаем отправку метрик в Pushgateway..."
metrics_data.each do |metric|
  success = send_metric_to_pushgateway(
    metric[:name], 
    metric[:type], 
    metric[:help], 
    metric[:data]
  )
  
  if success
    puts "✅ Метрика #{metric[:name]} успешно отправлена"
  else
    puts "❌ Не удалось отправить метрику #{metric[:name]}"
  end
end

puts "Отправка метрик завершена!" 