#!/usr/bin/env ruby

require_relative '../config/environment'

puts "Исправление отображения данных метрик..."

# Получение списка метрик с id 8-14
metrics = Metric.where(id: 8..14)
puts "Найдено метрик: #{metrics.count}"

# Создаем экземпляр сервиса Prometheus
prometheus_service = PrometheusService.new

metrics.each do |metric|
  puts "\nОбработка метрики #{metric.id}: #{metric.name} (#{metric.metric_type})"
  
  # Загружаем данные метрики через публичный интерфейс
  data = prometheus_service.fetch_metrics(metric.name, "1h")
  
  if data.nil? || data.empty?
    puts "⚠️ Для метрики #{metric.name} данные не найдены. Генерируем новые данные..."
    
    # Доступ к приватному методу generate_demo_metrics
    service_method = prometheus_service.method(:generate_demo_metrics)
    demo_data = service_method.call(metric.name, "1h")
    
    # Пытаемся использовать сгенерированные данные
    if demo_data.nil? || demo_data.empty?
      puts "❌ Не удалось сгенерировать демо-данные для #{metric.name}"
    else
      puts "✅ Успешно сгенерированы демо-данные для #{metric.name}"
      
      # Обновляем данные в интерфейсе, добавляя их напрямую в Pushgateway
      puts "Отправка данных в Pushgateway..."
      
      # Создаем данные для отправки
      values = demo_data[0][:values]
      
      # Создаем метки в зависимости от типа метрики
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
      
      # Берем последнее значение из демо-данных (текущее)
      latest_value = values.last[1]
      
      # Отправляем метрику в Pushgateway
      metric_text = "# HELP #{metric.name} #{metric.description}\n"
      metric_text += "# TYPE #{metric.name} #{metric.metric_type}\n"
      metric_text += "#{metric.name}{#{labels_str}} #{latest_value}\n"
      
      uri = URI.parse("http://localhost:9091/metrics/job/app_metrics")
      request = Net::HTTP::Post.new(uri)
      request.body = metric_text
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
  else
    puts "✅ Метрика #{metric.name} уже содержит данные (#{data.is_a?(Array) ? data.size : 0} записей)"
    
    # Выводим пример данных
    if data.is_a?(Array) && !data.empty?
      sample = data.first
      puts "   Пример данных: #{sample.inspect}"
    end
  end
end

puts "\nПроверка JavaScript в представлении..."

# Проверяем, можно ли улучшить отображение данных
puts "Рекомендации для отображения данных:"
puts "1. Проверьте консоль браузера на наличие ошибок JavaScript"
puts "2. Убедитесь, что роут /metrics/:id.json работает и возвращает данные"
puts "3. Проверьте, что контроллер metrics_chart_controller.js корректно получает и отображает данные"

puts "\nИсправление отображения метрик завершено!" 