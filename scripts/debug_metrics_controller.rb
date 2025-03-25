#!/usr/bin/env ruby

require_relative '../config/environment'

puts "Отладка контроллера метрик и отображения данных..."

# Проверка маршрутов
puts "1. Проверка маршрутов:"
metrics_routes = Rails.application.routes.routes.select { |r| r.path.spec.to_s.include?('/metrics') }
puts "Найдено #{metrics_routes.size} маршрутов, связанных с метриками"

# Проверка контроллера
puts "\n2. Проверка контроллера MetricsController:"
begin
  metrics_controller = MetricsController.new
  puts "✅ Контроллер MetricsController существует"
rescue => e
  puts "❌ Ошибка при создании контроллера: #{e.message}"
end

# Имитация запроса show для каждой метрики
puts "\n3. Тестирование метода show для каждой метрики:"
metrics = Metric.where(id: 8..14)

metrics.each do |metric|
  puts "\nТестирование отображения метрики #{metric.id}: #{metric.name} (#{metric.metric_type})"
  
  # Создаем тестовый запрос
  request = ActionDispatch::TestRequest.new({})
  response = ActionDispatch::TestResponse.new
  controller = MetricsController.new
  controller.request = request
  controller.response = response
  controller.params = { id: metric.id, format: 'json' }
  
  begin
    # Установка @metric без вызова фильтра
    controller.instance_variable_set('@metric', metric)
    
    # Напрямую получаем данные метрики
    metric_data = Metric.fetch_from_prometheus(metric.name, "1h")
    
    if metric_data.nil? || metric_data.empty?
      puts "⚠️ Для метрики #{metric.name} данные не найдены через Metric.fetch_from_prometheus"
    else
      count = metric_data.is_a?(Array) ? metric_data.size : 1
      puts "✅ Метрика #{metric.name} содержит данные через Metric.fetch_from_prometheus (#{count} записей)"
      
      # Выводим пример данных
      if metric_data.is_a?(Array) && !metric_data.empty?
        sample = metric_data.first
        puts "   Пример данных: #{sample.inspect}"
      end
    end
    
    # Создаем JSON-представление как в контроллере
    json_data = { metric: metric, data: metric_data }.as_json
    
    puts "JSON-ответ для JavaScript:"
    puts "   metric: id=#{json_data['metric']['id']}, name=#{json_data['metric']['name']}"
    puts "   data: #{json_data['data'] ? json_data['data'].length : 0} записей"
    
    if json_data['data'] && json_data['data'].is_a?(Array) && !json_data['data'].empty?
      first_item = json_data['data'].first
      
      if first_item && first_item['values'] && !first_item['values'].empty?
        point_count = first_item['values'].size
        sample_point = first_item['values'].first
        puts "   #{point_count} точек данных, пример: #{sample_point.inspect}"
      else
        puts "   ⚠️ Нет значений (values) в данных"
      end
    else
      puts "   ⚠️ Данные отсутствуют или некорректны для JavaScript"
    end
    
  rescue => e
    puts "❌ Ошибка при работе с метрикой #{metric.name}: #{e.message}"
    puts e.backtrace.join("\n")[0..500] # Ограничиваем вывод трассировки
  end
end

puts "\nПроверка JavaScript в представлении: рекомендации"
puts "1. Проверьте, что в консоли браузера нет ошибок при загрузке страницы"
puts "2. Проверьте запрос /metrics/:id.json в Network панели инструментов разработчика"
puts "3. Убедитесь, что JSON-ответ содержит правильный формат данных, как показано выше"
puts "4. Проверьте, что в metrics_chart_controller.js правильно обрабатываются полученные данные"

puts "\nПроверки завершены!" 