#!/usr/bin/env ruby

require_relative '../config/environment'
require 'net/http'
require 'uri'

puts "Обновление данных в Pushgateway для метрик..."

# Получение списка метрик
metrics = Metric.where(id: 8..14)
puts "Найдено метрик: #{metrics.count}"

# Адрес Pushgateway внутри контейнера
PUSHGATEWAY_URL = "http://pushgateway:9091"
puts "Используем Pushgateway по адресу: #{PUSHGATEWAY_URL}"

# Данные для метрик с учетом их типов
metrics.each do |metric|
  puts "\nОбновление метрики #{metric.id}: #{metric.name} (#{metric.metric_type})"
  
  # Генерируем тестовые данные в зависимости от типа метрики
  current_value = case metric.metric_type
    when "counter"
      # Для счетчиков используем значение от 100 до 10000
      rand(100..10000)
    when "gauge"
      # Для датчиков используем дробное значение
      rand(1..1000) / 10.0
    when "histogram"
      # Для гистограмм добавляем несколько бакетов
      value = rand(0.1..2.0)
      
      # Создаем текст с бакетами гистограммы
      buckets_text = ""
      [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].each do |bucket|
        buckets_text += "#{metric.name}_bucket{le=\"#{bucket}\""
        
        # Дополнительные метки
        case metric.name
          when 'http_request_duration_seconds'
            buckets_text += ",method=\"GET\",path=\"/api/data\""
          when 'sidekiq_job_duration_seconds'
            buckets_text += ",queue=\"default\",class=\"EmailJob\""
        end
        
        # Значение бакета (количество запросов меньше или равно границе)
        bucket_value = bucket >= value ? 1 : 0
        buckets_text += "} #{bucket_value}\n"
      end
      
      # Добавляем сумму и количество
      sum_text = "#{metric.name}_sum"
      count_text = "#{metric.name}_count"
      
      # Дополнительные метки
      case metric.name
        when 'http_request_duration_seconds'
          sum_text += "{method=\"GET\",path=\"/api/data\"}"
          count_text += "{method=\"GET\",path=\"/api/data\"}"
        when 'sidekiq_job_duration_seconds'
          sum_text += "{queue=\"default\",class=\"EmailJob\"}"
          count_text += "{queue=\"default\",class=\"EmailJob\"}"
      end
      
      sum_text += " #{value}\n"
      count_text += " 1\n"
      
      buckets_text + sum_text + count_text
    else
      rand(1..100)
  end
  
  # Для не-гистограмм создаем текст метрики
  unless metric.metric_type == "histogram"
    # Формируем метки в зависимости от типа метрики
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
    
    # Форматируем метки
    labels_str = labels.map { |k, v| "#{k}=\"#{v}\"" }.join(',')
    
    # Формируем текст метрики
    metric_text = "# HELP #{metric.name} #{metric.description}\n"
    metric_text += "# TYPE #{metric.name} #{metric.metric_type}\n"
    metric_text += "#{metric.name}{#{labels_str}} #{current_value}\n"
    
    current_value = metric_text
  end
  
  # Отправляем метрику в Pushgateway
  uri = URI.parse("#{PUSHGATEWAY_URL}/metrics/job/app_metrics")
  request = Net::HTTP::Post.new(uri)
  request.body = current_value.to_s
  request["Content-Type"] = "text/plain"
  
  begin
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
    
    if response.code.to_i >= 200 && response.code.to_i < 300
      puts "✅ Метрика #{metric.name} успешно отправлена в Pushgateway"
    else
      puts "❌ Ошибка при отправке метрики #{metric.name}: #{response.code} #{response.message}"
    end
  rescue => e
    puts "❌ Исключение при отправке метрики #{metric.name}: #{e.message}"
  end
end

puts "\nВсе метрики обновлены. Обновите страницу для просмотра данных." 