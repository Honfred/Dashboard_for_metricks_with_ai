# frozen_string_literal: true

module Demo
  # Модуль для генерации демонстрационных данных метрик
  # Вся логика вынесена из контроллера для удобства последующего удаления
  module MetricsData
    class << self
      # Генерирует демонстрационные данные для метрики
      # @param metric_name [String] имя метрики
      # @param time_range [String] временной диапазон (например, "1h", "24h", "7d")
      # @return [Array] массив с данными метрики в формате, совместимом с Prometheus
      def generate(metric_name, time_range = "1h")
        Rails.logger.info("Генерирую демонстрационные данные для метрики #{metric_name}, диапазон: #{time_range}")
        
        # Определяем временные параметры
        end_time = Time.now.to_i
        
        case time_range
        when "30m"
          start_time = end_time - 1800
          step = 30
        when "1h"
          start_time = end_time - 3600
          step = 60
        when "3h"
          start_time = end_time - 10800
          step = 180
        when "12h"
          start_time = end_time - 43200
          step = 720
        when "24h"
          start_time = end_time - 86400
          step = 1440
        when "7d"
          start_time = end_time - 604800
          step = 10080
        else
          start_time = end_time - 3600
          step = 60
        end
        
        # Находим метрику в базе данных
        metric = Metric.find_by(name: metric_name)
        return [] unless metric

        # Генерируем демо-данные в зависимости от типа метрики
        values = []
        
        # Параметры для создания реалистичных данных
        base_value = rand(10..100).to_f
        trend = rand(-0.5..0.5)
        variation = rand(1..10)
        
        # Для гистограмм и счетчиков имитируем больше точек данных
        point_count = metric.histogram? || metric.counter? ? 60 : 30
        time_step = (end_time - start_time) / point_count
        
        # Генерируем временной ряд с данными
        point_count.times do |i|
          point_time = start_time + i * time_step
          
          case metric.metric_type
          when "counter"
            # Для счетчиков создаем растущую линию с небольшими колебаниями
            value = base_value + (i * 5) + rand(-variation..variation)
          when "gauge"
            # Для датчиков создаем линию с более выраженными колебаниями
            value = base_value + (i * trend) + rand(-variation*2..variation*2)
          when "histogram"
            # Для гистограмм создаем нормальное распределение с несколькими пиками
            oscillation = Math.sin(i / 5.0) * variation * 2
            value = base_value + oscillation + rand(-variation..variation) 
          else
            value = base_value + rand(-variation..variation)
          end
          
          # Убеждаемся, что значение не отрицательное
          value = value.abs
          
          # Форматируем значение для красивого вывода
          formatted_value = "%.2f" % value
          
          # Добавляем точку в временной ряд
          values << [point_time, formatted_value]
        end
        
        # Возвращаем данные в формате, аналогичном Prometheus
        [{
          metric: {
            "__name__" => metric_name,
            "instance" => "demo:9090",
            "job" => "demo-metrics"
          },
          values: values
        }]
      end
    end
  end
end