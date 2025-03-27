# Class for generating test metrics data
class MetricsGenerator
  class << self
    def generate_test_data
      puts "Generating test metrics data..."
      
      # Generate metrics
      create_basic_metrics
      
      # Generate AI analyses
      create_ai_analyses
      
      # Generate alerts
      create_alerts
      
      puts "Test data generation completed!"
    end
    
    private
    
    def create_basic_metrics
      # Clean existing metrics if needed
      Metric.destroy_all if Metric.count > 0
      
      metrics_to_create = [
        { name: "http_request_duration_seconds", display_name: "Время отклика HTTP", metric_type: "histogram", description: "Гистограмма времени обработки HTTP-запросов в секундах", unit: "seconds" },
        { name: "http_requests_total", display_name: "Общее число HTTP запросов", metric_type: "counter", description: "Счетчик общего количества HTTP-запросов", unit: "requests" },
        { name: "http_error_rate", display_name: "Частота ошибок HTTP", metric_type: "gauge", description: "Процент HTTP-запросов, завершившихся с ошибкой", unit: "percent" },
        { name: "cpu_usage", display_name: "Использование CPU", metric_type: "gauge", description: "Процент использования CPU", unit: "percent" },
        { name: "memory_usage_bytes", display_name: "Использование памяти", metric_type: "gauge", description: "Объем используемой памяти в байтах", unit: "bytes" },
        { name: "disk_usage_percent", display_name: "Использование диска", metric_type: "gauge", description: "Процент использования дискового пространства", unit: "percent" }
      ]
      
      metrics_to_create.each do |metric_attrs|
        metric = Metric.create!(metric_attrs)
        puts "Created metric: #{metric.display_name}"
      end
      
      puts "Created #{Metric.count} metrics"
    end
    
    def create_ai_analyses
      # Clean existing AI analyses if needed
      AiAnalysis.destroy_all if AiAnalysis.count > 0
      
      analyses_to_create = [
        { metric_name: "http_request_duration_seconds", analysis_type: "anomaly", status: "warning", summary: "Обнаружены аномалии в времени отклика API", details: "Время отклика API превышает средние показатели на 35% в период с 14:00 до 15:30. Вероятная причина - увеличение нагрузки на базу данных.", timestamp: 2.hours.ago },
        { metric_name: "memory_usage_bytes", analysis_type: "trend", status: "critical", summary: "Обнаружен восходящий тренд использования памяти", details: "Наблюдается стабильный рост использования памяти на 5% каждый час. При сохранении текущей тенденции, предельное значение будет достигнуто через 4 часа.", timestamp: 5.hours.ago },
        { metric_name: "http_error_rate", analysis_type: "prediction", status: "info", summary: "Прогноз пиковой нагрузки", details: "На основании исторических данных прогнозируется пиковая нагрузка завтра с 12:00 до 14:00. Рекомендуется подготовить дополнительные ресурсы.", timestamp: 1.day.ago }
      ]
      
      analyses_to_create.each do |analysis_attrs|
        analysis = AiAnalysis.create!(analysis_attrs)
        puts "Created AI analysis: #{analysis.summary}"
      end
      
      puts "Created #{AiAnalysis.count} AI analyses"
    end
    
    def create_alerts
      # Clean existing alerts if needed
      Alert.destroy_all if Alert.count > 0
      
      alerts_to_create = [
        { name: "high_latency", metric_name: "http_request_duration_seconds", condition: "> 2.0", severity: "warning", description: "Время отклика API превышает 2 секунды", active: true, triggered_at: 30.minutes.ago },
        { name: "high_error_rate", metric_name: "http_error_rate", condition: "> 0.05", severity: "critical", description: "Уровень ошибок превышает 5%", active: true, triggered_at: 15.minutes.ago },
        { name: "disk_space_low", metric_name: "disk_usage_percent", condition: "> 90", severity: "critical", description: "Заканчивается место на диске (использовано более 90%)", active: false, triggered_at: 2.days.ago }
      ]
      
      alerts_to_create.each do |alert_attrs|
        alert = Alert.create!(alert_attrs)
        puts "Created alert: #{alert.name}"
      end
      
      puts "Created #{Alert.count} alerts"
    end
  end
end 