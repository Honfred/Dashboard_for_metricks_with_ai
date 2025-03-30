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
      
      # Создадим маппинг имён метрик на ID
      metrics_map = {}
      Metric.all.each do |metric|
        metrics_map[metric.name] = metric.id
      end
      
      # Маппинг типов анализа на значения из enum
      analysis_type_map = {
        "anomaly" => "anomaly_detection",
        "trend" => "trend_prediction",
        "prediction" => "performance_insight"
      }
      
      analyses_to_create = [
        { metric_name: "http_request_duration_seconds", analysis_type: "anomaly", summary: "Обнаружены аномалии в времени отклика API", details: "Время отклика API превышает средние показатели на 35% в период с 14:00 до 15:30. Вероятная причина - увеличение нагрузки на базу данных.", timestamp: 2.hours.ago },
        { metric_name: "memory_usage_bytes", analysis_type: "trend", summary: "Обнаружен восходящий тренд использования памяти", details: "Наблюдается стабильный рост использования памяти на 5% каждый час. При сохранении текущей тенденции, предельное значение будет достигнуто через 4 часа.", timestamp: 5.hours.ago },
        { metric_name: "http_error_rate", analysis_type: "prediction", summary: "Прогноз пиковой нагрузки", details: "На основании исторических данных прогнозируется пиковая нагрузка завтра с 12:00 до 14:00. Рекомендуется подготовить дополнительные ресурсы.", timestamp: 1.day.ago }
      ]
      
      analyses_to_create.each do |analysis_attrs|
        metric_name = analysis_attrs.delete(:metric_name)
        metric_id = metrics_map[metric_name]
        
        if metric_id.nil?
          puts "Skipping analysis for unknown metric: #{metric_name}"
          next
        end
        
        # Преобразуем тип анализа
        original_type = analysis_attrs.delete(:analysis_type)
        enum_type = analysis_type_map[original_type] || "anomaly_detection"
        
        # Создаем результаты анализа
        timestamp = analysis_attrs.delete(:timestamp) || Time.now
        results = {
          summary: analysis_attrs[:summary],
          details: analysis_attrs[:details],
          timestamp: timestamp.to_i,
          status: analysis_attrs[:status] || "info"
        }
        
        # Создаем запись анализа
        analysis = AiAnalysis.create!(
          metric_id: metric_id,
          analysis_type: enum_type,
          parameters: { timestamp: timestamp.to_i },
          results: results
        )
        
        puts "Created AI analysis: #{results[:summary]}"
      end
      
      puts "Created #{AiAnalysis.count} AI analyses"
    end
    
    def create_alerts
      # Clean existing alerts if needed
      Alert.destroy_all if Alert.count > 0
      
      alerts_to_create = [
        { 
          service: "api", 
          metric: "http_request_duration_seconds", 
          value: 2.5, 
          threshold: 2.0, 
          status: "triggered", 
          severity: "warning", 
          message: "Время отклика API превышает 2 секунды", 
          triggered_at: 30.minutes.ago 
        },
        { 
          service: "web", 
          metric: "http_error_rate", 
          value: 0.07, 
          threshold: 0.05, 
          status: "triggered", 
          severity: "critical", 
          message: "Уровень ошибок превышает 5%", 
          triggered_at: 15.minutes.ago 
        },
        { 
          service: "db", 
          metric: "disk_usage_percent", 
          value: 95.0, 
          threshold: 90.0, 
          status: "resolved", 
          severity: "critical", 
          message: "Заканчивается место на диске (использовано более 90%)", 
          triggered_at: 2.days.ago,
          resolved_at: 1.day.ago
        }
      ]
      
      alerts_to_create.each do |alert_attrs|
        alert = Alert.create!(alert_attrs)
        puts "Created alert: #{alert.service} - #{alert.metric} (#{alert.severity})"
      end
      
      puts "Created #{Alert.count} alerts"
    end
  end
end 