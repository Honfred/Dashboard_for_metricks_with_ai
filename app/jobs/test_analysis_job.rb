class TestAnalysisJob < ApplicationJob
  queue_as :default

  def perform(ai_analysis_id)
    Rails.logger.info("TestAnalysisJob: Starting test analysis for ID: #{ai_analysis_id}")
    
    ai_analysis = AiAnalysis.find_by(id: ai_analysis_id)
    return unless ai_analysis
    
    # Обновляем статус на "processing"
    ai_analysis.update(status: 'processing')
    Rails.logger.info("TestAnalysisJob: Analysis status set to 'processing'")
    
    # Имитируем задержку обработки
    sleep 3
    
    # Генерируем тестовые результаты в зависимости от типа анализа
    result = generate_test_result_for(ai_analysis.analysis_type)
    
    Rails.logger.info("TestAnalysisJob: Generated test result with status: #{result["status"]}")
    
    # Сохраняем результаты анализа
    ai_analysis.update(
      status: "completed",
      results: result,
      completed_at: Time.current
    )
    
    # Генерируем тестовый отчет
    report = generate_test_report_for(ai_analysis.analysis_type, ai_analysis.metric.name)
    
    # Сохраняем отчет
    ai_analysis.update(report: report)
    
    Rails.logger.info("TestAnalysisJob: Test analysis completed successfully")
  end
  
  private
  
  def generate_test_result_for(analysis_type)
    case analysis_type
    when 'anomaly_detection'
      generate_test_anomaly_result
    when 'trend_prediction'
      generate_test_trend_result
    when 'performance_insight'
      generate_test_performance_result
    else
      { "status" => "error", "message" => "Неизвестный тип анализа" }
    end
  end
  
  def generate_test_anomaly_result
    # Генерируем случайные аномалии
    anomalies_count = rand(2..5)
    current_time = Time.now.to_i
    
    anomalies = []
    anomalies_count.times do |i|
      anomalies << {
        "timestamp" => current_time - i * 3600,
        "value" => rand(80..120),
        "score" => rand(0.6..0.9)
      }
    end
    
    {
      "status" => "success",
      "anomalies" => anomalies,
      "anomalies_count" => 100,
      "model_info" => {
        "name" => "test_anomaly_model",
        "version" => "1.0",
        "accuracy" => 0.92
      }
    }
  end
  
  def generate_test_trend_result
    # Генерируем прогноз тренда
    periods = 24
    current_time = Time.now.to_i
    prediction = []
    
    base_value = rand(50..100)
    trend_factor = [-1, 1].sample * rand(0.05..0.2) # случайный тренд вверх или вниз
    
    periods.times do |i|
      prediction << {
        "timestamp" => current_time + i * 3600,
        "value" => base_value * (1 + trend_factor * i)
      }
    end
    
    {
      "status" => "success",
      "prediction" => prediction,
      "model_info" => {
        "name" => "test_trend_model",
        "version" => "1.0",
        "accuracy" => 0.85
      }
    }
  end
  
  def generate_test_performance_result
    # Генерируем анализ производительности
    predictions = 20.times.map { rand(30..200) }
    
    {
      "status" => "success",
      "predictions" => predictions,
      "feature_importance" => {
        "0" => 0.45,
        "1" => 0.35,
        "2" => 0.2
      },
      "model_info" => {
        "name" => "test_performance_model",
        "version" => "1.0",
        "accuracy" => 0.88
      }
    }
  end
  
  def generate_test_report_for(analysis_type, metric_name)
    case analysis_type
    when 'anomaly_detection'
      {
        "insights" => [
          {
            "title" => "Обнаружены аномалии в метрике #{metric_name}",
            "description" => "Обнаружено несколько аномальных значений, требующих внимания",
            "severity" => "medium",
            "recommendation" => "Рекомендуется проверить системные процессы в указанное время"
          },
          {
            "title" => "Обнаружен временной паттерн аномалий",
            "description" => "Большинство аномалий происходит в утренние часы с 8:00 до 11:00",
            "severity" => "low",
            "recommendation" => "Проверьте активность системы в указанные периоды времени"
          }
        ],
        "statistics" => {
          "Всего точек данных" => 100,
          "Обнаружено аномалий" => rand(2..5),
          "Процент аномалий" => "#{rand(2..8)}%"
        },
        "events" => [
          {
            "timestamp" => Time.now.to_i - 3600,
            "type" => "anomaly",
            "value" => 95.4,
            "deviation" => 68.2,
            "description" => "Аномальное значение метрики #{metric_name}"
          },
          {
            "timestamp" => Time.now.to_i - 7200,
            "type" => "anomaly",
            "value" => 105.7,
            "deviation" => 72.5,
            "description" => "Аномальное значение метрики #{metric_name}"
          }
        ]
      }
    when 'trend_prediction'
      trend_percentage = rand(-20..30)
      {
        "insights" => [
          {
            "title" => "Прогноз для метрики #{metric_name} показывает #{trend_percentage > 0 ? "рост" : "снижение"}",
            "description" => "Ожидается изменение на #{trend_percentage}% в течение следующих 24 часов",
            "severity" => trend_percentage.abs > 15 ? "medium" : "low",
            "recommendation" => trend_percentage > 20 ? "Рекомендуется увеличить ресурсы системы" : nil
          }
        ],
        "statistics" => {
          "Текущее значение" => rand(50..100).to_f.round(2),
          "Среднее прогнозируемое значение" => rand(50..100).to_f.round(2),
          "Изменение" => "#{trend_percentage > 0 ? '+' : ''}#{trend_percentage}%"
        },
        "events" => 5.times.map do |i|
          {
            "timestamp" => Time.now.to_i + i * 14400, # каждые 4 часа
            "type" => "prediction",
            "value" => rand(50..100).to_f.round(2),
            "deviation" => rand(-15..15).to_f.round(2),
            "description" => "Прогноз метрики #{metric_name}"
          }
        end
      }
    when 'performance_insight'
      {
        "insights" => [
          {
            "title" => "Анализ производительности для #{metric_name}",
            "description" => "Основные факторы, влияющие на метрику: CPU (45%), Память (35%), Запросы (20%)",
            "severity" => "medium",
            "recommendation" => "Для оптимизации производительности рекомендуется уменьшить нагрузку на CPU"
          },
          {
            "title" => "Обнаружен большой разброс значений",
            "description" => "Разница между минимальным и максимальным значением составляет 68% от среднего",
            "severity" => "medium",
            "recommendation" => "Рекомендуется оптимизировать систему для более стабильной производительности"
          }
        ],
        "statistics" => {
          "Минимальное значение" => 45.8,
          "Максимальное значение" => 178.3,
          "Среднее значение" => 87.2
        },
        "events" => [
          {
            "timestamp" => Time.now.to_i,
            "type" => "insight",
            "value" => 178.3,
            "deviation" => 104.5,
            "description" => "Обнаружены потенциально критические значения метрики #{metric_name}"
          }
        ],
        "feature_importance" => {
          "0" => 0.45,
          "1" => 0.35,
          "2" => 0.2
        }
      }
    else
      {
        "insights" => [],
        "statistics" => {},
        "events" => []
      }
    end
  end
end