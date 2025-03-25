#!/usr/bin/env ruby

require_relative '../config/environment'

# Для каждой метрики создаем тестовые данные в Prometheus
metrics = Metric.where(id: 8..14)
puts "Найдено метрик: #{metrics.count}"

metrics.each do |metric|
  puts "Создание тестовых данных для метрики #{metric.id}: #{metric.name} (#{metric.metric_type})"
  
  # Генерируем демонстрационные данные
  end_time = Time.now.to_i
  start_time = end_time - 3600 # за последний час
  step = 60 # шаг в 60 секунд
  
  # Параметры для создания реалистичных данных
  base_value = rand(10..100).to_f
  trend = rand(-0.5..0.5)
  variation = rand(1..10)
  
  # Генерируем временной ряд с данными
  values = []
  current_time = start_time
  
  while current_time <= end_time
    case metric.metric_type
    when "counter"
      # Для счетчиков создаем растущую линию с небольшими колебаниями
      value = base_value + ((current_time - start_time) * 0.01) + rand(-variation..variation)
    when "gauge"
      # Для датчиков создаем линию с более выраженными колебаниями
      value = base_value + ((current_time - start_time) * trend * 0.001) + rand(-variation*2..variation*2)
    when "histogram", "summary"
      # Для распределений и сводок создаем линию с периодическими колебаниями
      cycle = Math.sin((current_time - start_time) / 1800.0) * variation
      value = base_value + cycle + rand(-variation/2..variation/2)
    else
      value = base_value + rand(-variation..variation)
    end
    
    # Убеждаемся, что значение не отрицательное
    value = value.abs
    
    # Форматируем значение для красивого вывода
    formatted_value = "%.2f" % value
    
    # Добавляем точку в временной ряд
    values << [current_time, formatted_value]
    
    # Переходим к следующей временной точке
    current_time += step
  end
  
  # Для отображения результатов создаем подходящие метки (labels)
  labels = case metric.name
    when 'http_request_duration_seconds'
      { method: 'GET', path: '/api/data' }
    when 'http_requests_total'
      { method: 'GET', path: '/api/data', status: '200' }
    when 'http_requests_errors_total'
      { method: 'GET', path: '/api/data', status: '500' }
    when 'process_cpu_seconds_total'
      { service: 'web' }
    when 'process_resident_memory_bytes'
      { service: 'web' }
    when 'sidekiq_job_duration_seconds'
      { queue: 'default', class: 'EmailJob' }
    when 'up'
      { service: 'web' }
    else
      { service: 'test' }
  end
  
  # Создание метрик в PrometheusService
  # Мы используем метод generate_demo_metrics, который является приватным,
  # поэтому сначала получаем его, а затем вызываем
  service = PrometheusService.new
  service_method = service.method(:generate_demo_metrics)
  service_method.call(metric.name, metric.metric_type)
  
  puts "Тестовые данные созданы для метрики #{metric.name}"
end

puts "Готово! Все метрики должны теперь отображать данные." 