#!/usr/bin/env ruby

require_relative '../config/environment'

# Получаем все метрики из базы данных
metrics = Metric.all
puts "Найдено метрик: #{metrics.count}"

# Для каждой метрики генерируем тестовые данные
metrics.each do |metric|
  puts "Генерация тестовых данных для метрики: #{metric.name} (#{metric.metric_type})"
  
  # Создаем тестовые данные в зависимости от типа метрики
  case metric.name
  when "http_request_duration_seconds"
    # Для http_request_duration_seconds создаем данные с разными методами и путями
    data = [
      { method: "GET", path: "/api/data", value: 0.345 },
      { method: "POST", path: "/api/data", value: 0.567 },
      { method: "GET", path: "/api/users", value: 0.123 }
    ]
    
    data.each do |item|
      metric_name = "#{metric.name}{method=\"#{item[:method]}\",path=\"#{item[:path]}\"}"
      puts "  #{metric_name} #{item[:value]}"
    end
    
  when "http_requests_total"
    # Для http_requests_total создаем данные с разными методами, путями и статусами
    data = [
      { method: "GET", path: "/api/data", status: "200", value: 1234 },
      { method: "POST", path: "/api/data", status: "200", value: 456 },
      { method: "GET", path: "/api/users", status: "200", value: 789 }
    ]
    
    data.each do |item|
      metric_name = "#{metric.name}{method=\"#{item[:method]}\",path=\"#{item[:path]}\",status=\"#{item[:status]}\"}"
      puts "  #{metric_name} #{item[:value]}"
    end
    
  when "http_requests_errors_total"
    # Для http_requests_errors_total создаем данные с разными методами, путями и статусами ошибок
    data = [
      { method: "GET", path: "/api/data", status: "500", value: 78 },
      { method: "POST", path: "/api/data", status: "422", value: 45 },
      { method: "GET", path: "/api/users", status: "404", value: 123 }
    ]
    
    data.each do |item|
      metric_name = "#{metric.name}{method=\"#{item[:method]}\",path=\"#{item[:path]}\",status=\"#{item[:status]}\"}"
      puts "  #{metric_name} #{item[:value]}"
    end
    
  when "process_cpu_seconds_total"
    # Для process_cpu_seconds_total создаем данные
    data = [
      { service: "web", value: 123.45 },
      { service: "sidekiq", value: 67.89 }
    ]
    
    data.each do |item|
      metric_name = "#{metric.name}{service=\"#{item[:service]}\"}"
      puts "  #{metric_name} #{item[:value]}"
    end
    
  when "process_resident_memory_bytes"
    # Для process_resident_memory_bytes создаем данные
    data = [
      { service: "web", value: 256000000 },
      { service: "sidekiq", value: 128000000 }
    ]
    
    data.each do |item|
      metric_name = "#{metric.name}{service=\"#{item[:service]}\"}"
      puts "  #{metric_name} #{item[:value]}"
    end
    
  when "sidekiq_job_duration_seconds"
    # Для sidekiq_job_duration_seconds создаем данные
    data = [
      { queue: "default", class: "EmailJob", value: 0.56 },
      { queue: "high", class: "NotificationJob", value: 0.78 },
      { queue: "low", class: "ReportJob", value: 1.23 }
    ]
    
    data.each do |item|
      metric_name = "#{metric.name}{queue=\"#{item[:queue]}\",class=\"#{item[:class]}\"}"
      puts "  #{metric_name} #{item[:value]}"
    end
    
  when "up"
    # Для up создаем данные
    data = [
      { service: "web", value: 1 },
      { service: "sidekiq", value: 1 },
      { service: "database", value: 1 }
    ]
    
    data.each do |item|
      metric_name = "#{metric.name}{service=\"#{item[:service]}\"}"
      puts "  #{metric_name} #{item[:value]}"
    end
  end
  
  # Используем PrometheusService для получения метрик
  puts "Получение метрик из Prometheus:"
  result = Metric.fetch_from_prometheus(metric.name, "1h")
  puts "  Результат: #{result.inspect}"
end

puts "Готово!" 