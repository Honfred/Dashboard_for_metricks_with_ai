#!/usr/bin/env ruby

require_relative '../config/environment'

puts "Проверка прямого получения данных метрик из Prometheus..."

metrics = Metric.where(id: 8..14)
puts "Найдено метрик: #{metrics.count}"

prometheus_service = PrometheusService.new

metrics.each do |metric|
  puts "Получение данных для метрики #{metric.id}: #{metric.name} (#{metric.metric_type})"
  
  # Получаем данные напрямую через PrometheusService
  begin
    result = prometheus_service.fetch_metrics(metric.name, "1h")
    
    if result.nil? || result.empty?
      puts "⚠️ Для метрики #{metric.name} данные не найдены"
    else
      count = result.is_a?(Array) ? result.size : 1
      puts "✅ Метрика #{metric.name} содержит данные (#{count} записей)"
      
      # Выводим пример данных
      if result.is_a?(Array) && !result.empty?
        sample = result.first
        puts "   Пример данных: #{sample.inspect}"
      else
        puts "   Данные: #{result.inspect}"
      end
    end
  rescue => e
    puts "❌ Ошибка при получении данных для метрики #{metric.name}: #{e.message}"
  end
  
  puts "-" * 50
end

puts "Проверка завершена" 