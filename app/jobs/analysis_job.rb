class AnalysisJob < ApplicationJob
  include MetricDataFetchable
  queue_as :ml

  def perform(ai_analysis_id)
    Rails.logger.info("AnalysisJob: Starting analysis for ID: #{ai_analysis_id}")
    
    ai_analysis = AiAnalysis.find_by(id: ai_analysis_id)
    unless ai_analysis
      Rails.logger.error("AnalysisJob: Analysis with ID #{ai_analysis_id} not found")
      return
    end
    
    # Обновляем статус на "processing"
    ai_analysis.update(status: 'processing')
    Rails.logger.info("AnalysisJob: Analysis status set to 'processing'")
    
    metric = ai_analysis.metric
    unless metric
      Rails.logger.error("AnalysisJob: Metric not found for analysis #{ai_analysis_id}")
      ai_analysis.update(status: 'failed', results: { "status" => "error", "message" => "Метрика не найдена" })
      return
    end
    
    Rails.logger.info("AnalysisJob: Fetching data for metric #{metric.name} with type #{ai_analysis.analysis_type}")

    # Получаем данные метрики за соответствующий период
    data = case ai_analysis.analysis_type
      when 'anomaly_detection'
        fetch_metric_data(metric, 1.week.ago, Time.now)
      when 'trend_prediction'
        fetch_metric_data(metric, 1.month.ago, Time.now)
      when 'performance_insight'
        fetch_performance_data(metric, 1.month.ago, Time.now)
    end

    if data[:values].blank?
      Rails.logger.error("AnalysisJob: No data found for metric #{metric.name}")
      ai_analysis.update(
        status: 'failed',
        results: { "status" => "error", "message" => "Нет данных для анализа метрики" },
        completed_at: Time.current
      )
      return
    end
    
    Rails.logger.info("AnalysisJob: Got #{data[:values].size} data points for analysis")

    begin
      # Получаем результаты анализа используя соответствующую обученную модель
      Rails.logger.info("AnalysisJob: Calling ML service for #{ai_analysis.analysis_type}")
      
      result = case ai_analysis.analysis_type
        when 'anomaly_detection'
          detect_anomalies(metric.name, data)
        when 'trend_prediction'
          predict_trend(metric.name, data)
        when 'performance_insight'
          analyze_performance(metric.name, data)
      end
      
      Rails.logger.info("AnalysisJob: ML service response status: #{result["status"]}")

      # Сохраняем результаты анализа
      ai_analysis.update(
        status: result["status"] == "success" ? "completed" : "failed",
        results: result,
        completed_at: Time.current
      )

      # Создаем отчет по анализу
      if result["status"] == "success"
        Rails.logger.info("AnalysisJob: Generating report for successful analysis")
        generate_analysis_report(ai_analysis, result)
      else
        Rails.logger.error("AnalysisJob: Analysis failed with message: #{result["message"]}")
      end
      
    rescue => e
      Rails.logger.error("AnalysisJob: Exception during analysis: #{e.class.name} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      ai_analysis.update(
        status: 'failed',
        results: { "status" => "error", "message" => "Ошибка в процессе анализа: #{e.message}" },
        completed_at: Time.current
      )
    end
    
    Rails.logger.info("AnalysisJob: Analysis completed with status #{ai_analysis.status}")
  end

  private

  # Обнаружение аномалий
  def detect_anomalies(metric_name, data)
    MlService.detect_anomalies(metric_name, data[:values], data[:timestamps])
  end

  # Прогнозирование трендов
  def predict_trend(metric_name, data)
    result = MlService.predict_trend(metric_name, 24) # Прогноз на 24 часа вперед
    
    # Добавляем текущие данные для отображения графика
    if result["status"] == "success"
      result["current_data"] = {
        timestamps: data[:timestamps],
        values: data[:values]
      }
    end
    
    result
  end

  # Анализ производительности
  def analyze_performance(metric_name, data)
    # Собираем признаки в зависимости от типа метрики
    features = case metric_name
      when "cpu_usage"
        # Признаки: память и количество запросов
        prepare_cpu_features(data)
      when "memory_usage_bytes"
        # Признаки: активные пользователи и запросы
        prepare_memory_features(data)
      when "http_request_duration_seconds"
        # Признаки: CPU, память и запросы
        prepare_http_features(data)
      else
        []
    end
    
    return { "status" => "error", "message" => "Недостаточно данных для анализа" } if features.blank?
    
    MlService.analyze_performance(metric_name, features)
  end

  # Методы для подготовки признаков для разных метрик
  def prepare_cpu_features(data)
    # В реальном приложении здесь будет логика сбора данных о памяти и запросах
    # Упрощенный пример:
    memory_data = fetch_related_metric_data("memory_usage_bytes", data[:start_time], data[:end_time])
    requests_data = fetch_related_metric_data("http_requests_total", data[:start_time], data[:end_time])
    
    # Формируем пары признаков: [память, запросы]
    memory_data.zip(requests_data).map { |memory, requests| [memory, requests] }
  end

  def prepare_memory_features(data)
    # Упрощенный пример:
    users_data = fetch_related_metric_data("active_users", data[:start_time], data[:end_time])
    requests_data = fetch_related_metric_data("http_requests_total", data[:start_time], data[:end_time])
    
    # Формируем пары признаков: [пользователи, запросы]
    users_data.zip(requests_data).map { |users, requests| [users, requests] }
  end

  def prepare_http_features(data)
    # Упрощенный пример:
    cpu_data = fetch_related_metric_data("cpu_usage", data[:start_time], data[:end_time])
    memory_data = fetch_related_metric_data("memory_usage_bytes", data[:start_time], data[:end_time])
    requests_data = fetch_related_metric_data("http_requests_total", data[:start_time], data[:end_time])
    
    # Формируем тройки признаков: [cpu, память, запросы]
    cpu_data.zip(memory_data, requests_data).map { |cpu, memory, requests| [cpu, memory, requests] }
  end

  # Вспомогательный метод для получения данных связанных метрик
  def fetch_related_metric_data(metric_name, start_time, end_time)
    related_metric = Metric.find_by(name: metric_name)
    return [] unless related_metric
    
    data = fetch_metric_data(related_metric, start_time, end_time)
    data[:values] || []
  end

  # Генерация отчета по анализу
  def generate_analysis_report(ai_analysis, result)
    report = {
      insights: [],
      statistics: {},
      events: []
    }
    
    case ai_analysis.analysis_type
    when 'anomaly_detection'
      generate_anomaly_report(report, result, ai_analysis.metric)
    when 'trend_prediction'
      generate_trend_report(report, result, ai_analysis.metric)
    when 'performance_insight'
      generate_performance_report(report, result, ai_analysis.metric)
    end
    
    # Сохраняем готовый отчет
    ai_analysis.update(report: report)
  end

  # Генерация отчета для аномалий
  def generate_anomaly_report(report, result, metric)
    anomalies_count = result["anomalies"].size
    total_points = result["anomalies_count"] || 0
    anomaly_rate = total_points > 0 ? (anomalies_count.to_f / total_points * 100).round(2) : 0
    
    # Статистика
    report[:statistics] = {
      "Всего точек данных" => total_points,
      "Обнаружено аномалий" => anomalies_count,
      "Процент аномалий" => "#{anomaly_rate}%"
    }
    
    # Выводы ИИ
    if anomalies_count > 0
      severity = case
        when anomaly_rate >= 15 then "high"
        when anomaly_rate >= 5 then "medium"
        else "low"
      end
      
      report[:insights] << {
        "title" => "Обнаружены аномалии в метрике #{metric.name}",
        "description" => "Обнаружено #{anomalies_count} аномальных значений (#{anomaly_rate}% от всех данных)",
        "severity" => severity,
        "recommendation" => generate_recommendation_for_metric(metric, severity)
      }
      
      # Выявление паттернов аномалий
      if anomalies_count >= 3
        time_patterns = detect_time_patterns(result["anomalies"])
        if time_patterns
          report[:insights] << {
            "title" => "Обнаружен временной паттерн аномалий",
            "description" => "#{time_patterns}",
            "severity" => "medium",
            "recommendation" => "Проверьте активность системы в указанные периоды времени"
          }
        end
      end
    else
      report[:insights] << {
        "title" => "Аномалий не обнаружено",
        "description" => "Метрика #{metric.name} работает в нормальном режиме",
        "severity" => "low"
      }
    end
    
    # События (аномалии)
    result["anomalies"].each do |anomaly|
      report[:events] << {
        "timestamp" => anomaly["timestamp"],
        "type" => "anomaly",
        "value" => anomaly["value"].is_a?(Array) ? anomaly["value"].first : anomaly["value"],
        "deviation" => ((anomaly["score"].abs) * 100).round(2),
        "description" => "Аномальное значение метрики #{metric.name}"
      }
    end
  end

  # Генерация отчета для трендов
  def generate_trend_report(report, result, metric)
    predictions = result["prediction"] || []
    current_data = result["current_data"] || {}
    current_values = current_data[:values] || []
    
    # Статистика
    last_value = current_values.last
    predicted_values = predictions.map { |p| p["value"] }
    average_prediction = predicted_values.sum / predicted_values.size rescue 0
    trend_percentage = last_value && last_value != 0 ? ((average_prediction - last_value) / last_value * 100).round(2) : 0
    
    report[:statistics] = {
      "Текущее значение" => last_value&.round(2) || "Н/Д",
      "Среднее прогнозируемое значение" => average_prediction.round(2),
      "Изменение" => "#{trend_percentage > 0 ? '+' : ''}#{trend_percentage}%"
    }
    
    # Выводы ИИ
    trend_direction = case
      when trend_percentage >= 10 then "значительный рост"
      when trend_percentage > 0 then "умеренный рост"
      when trend_percentage == 0 then "стабильность"
      when trend_percentage >= -10 then "умеренное снижение"
      else "значительное снижение"
    end
    
    severity = case
      when trend_percentage.abs >= 20 then "high"
      when trend_percentage.abs >= 5 then "medium"
      else "low"
    end
    
    report[:insights] << {
      "title" => "Прогноз для метрики #{metric.name} показывает #{trend_direction}",
      "description" => "Ожидается изменение на #{trend_percentage}% в течение следующих 24 часов",
      "severity" => severity,
      "recommendation" => trend_percentage >= 20 ? "Рекомендуется увеличить ресурсы системы для обеспечения стабильной работы" : nil
    }
    
    # Определяем волатильность тренда
    volatility = calculate_volatility(predicted_values)
    if volatility > 0.2
      report[:insights] << {
        "title" => "Высокая волатильность прогноза",
        "description" => "Метрика #{metric.name} может демонстрировать нестабильное поведение в будущем",
        "severity" => "medium",
        "recommendation" => "Рекомендуется более частый мониторинг данной метрики"
      }
    end
    
    # События (прогнозы)
    predictions.each_with_index do |pred, i|
      next if i % 4 != 0  # Берем каждую 4-ую точку для уменьшения количества событий
      
      deviation = last_value && last_value != 0 ? ((pred["value"] - last_value) / last_value * 100).round(2) : 0
      
      report[:events] << {
        "timestamp" => pred["timestamp"],
        "type" => "prediction",
        "value" => pred["value"].round(2),
        "deviation" => deviation,
        "description" => "Прогноз метрики #{metric.name}"
      }
    end
  end

  # Генерация отчета для производительности
  def generate_performance_report(report, result, metric)
    predictions = result["predictions"] || []
    feature_importance = result["feature_importance"] || {}
    
    # Находим минимальное и максимальное значения
    min_value = predictions.min rescue 0
    max_value = predictions.max rescue 0
    avg_value = predictions.sum / predictions.size rescue 0
    
    # Статистика
    report[:statistics] = {
      "Минимальное значение" => min_value.round(2),
      "Максимальное значение" => max_value.round(2),
      "Среднее значение" => avg_value.round(2)
    }
    
    # Выводы ИИ - определяем, какие факторы наиболее важны
    important_factors = []
    feature_importance.sort_by { |_, v| -v }.each do |factor, importance|
      factor_index = factor.to_i
      factor_name = case metric.name
        when "cpu_usage" 
          factor_index == 0 ? "Память" : "Количество запросов"
        when "memory_usage_bytes"
          factor_index == 0 ? "Активные пользователи" : "Количество запросов"
        when "http_request_duration_seconds"
          case factor_index
          when 0 then "CPU"
          when 1 then "Память"
          when 2 then "Количество запросов"
          end
      end
      
      important_factors << "#{factor_name} (#{(importance * 100).round(2)}%)"
    end
    
    report[:insights] << {
      "title" => "Анализ производительности для #{metric.name}",
      "description" => "Основные факторы, влияющие на метрику: #{important_factors.join(', ')}",
      "severity" => "medium",
      "recommendation" => generate_performance_recommendation(metric.name, feature_importance)
    }
    
    # При большом разбросе значений, добавляем дополнительное наблюдение
    range = max_value - min_value
    if range > (avg_value * 0.5)
      report[:insights] << {
        "title" => "Обнаружен большой разброс значений",
        "description" => "Разница между минимальным и максимальным значением составляет #{((range / avg_value) * 100).round(2)}% от среднего",
        "severity" => "medium",
        "recommendation" => "Рекомендуется оптимизировать систему для более стабильной производительности"
      }
    end
    
    # События - добавляем виртуальные события для критических значений производительности
    if predictions.any?
      threshold = avg_value * 1.5
      high_values = predictions.select { |p| p > threshold }
      if high_values.any?
        report[:events] << {
          "timestamp" => Time.now.to_i,
          "type" => "insight",
          "value" => high_values.max.round(2),
          "deviation" => ((high_values.max / avg_value - 1) * 100).round(2),
          "description" => "Обнаружены потенциально критические значения метрики #{metric.name}"
        }
      end
    end
  end

  # Вспомогательные методы для выводов ИИ
  
  def detect_time_patterns(anomalies)
    return nil if anomalies.size < 3
    
    times = anomalies.map { |a| Time.at(a["timestamp"]) }
    
    # Проверка на время суток
    hour_counts = times.group_by { |t| t.hour }.transform_values(&:size)
    max_hour_count = hour_counts.values.max
    if max_hour_count >= anomalies.size * 0.5
      peak_hours = hour_counts.select { |_, count| count >= max_hour_count * 0.7 }
                            .keys.sort.map { |h| "#{h}:00" }
      return "Большинство аномалий происходит в следующие часы: #{peak_hours.join(', ')}"
    end
    
    # Проверка на день недели
    day_counts = times.group_by { |t| t.wday }.transform_values(&:size)
    max_day_count = day_counts.values.max
    if max_day_count >= anomalies.size * 0.5
      days = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
      peak_days = day_counts.select { |_, count| count >= max_day_count * 0.7 }
                          .keys.sort.map { |d| days[d] }
      return "Большинство аномалий происходит в следующие дни: #{peak_days.join(', ')}"
    end
    
    nil
  end
  
  def calculate_volatility(values)
    return 0 if values.size < 2
    
    diffs = values.each_cons(2).map { |a, b| ((b - a) / a).abs rescue 0 }
    diffs.sum / diffs.size rescue 0
  end
  
  def generate_recommendation_for_metric(metric, severity)
    case metric.name
    when "cpu_usage"
      case severity
      when "high"
        "Рекомендуется проверить процессы, потребляющие наибольшее количество CPU, и рассмотреть возможность масштабирования системы"
      when "medium"
        "Следите за тенденцией потребления CPU, возможно потребуется оптимизация процессов"
      else
        "Продолжайте регулярный мониторинг CPU"
      end
    when "memory_usage_bytes"
      case severity
      when "high"
        "Проверьте процессы на наличие утечек памяти и рассмотрите возможность увеличения доступной памяти системы"
      when "medium"
        "Следите за тенденцией потребления памяти, возможно потребуется оптимизация управления памятью"
      else
        "Продолжайте регулярный мониторинг использования памяти"
      end
    when "http_request_duration_seconds"
      case severity
      when "high"
        "Рекомендуется проверить серверную нагрузку и оптимизировать обработку запросов или увеличить мощность серверов"
      when "medium"
        "Следите за временем ответа сервера и подготовьте план действий при его дальнейшем увеличении"
      else
        "Продолжайте регулярный мониторинг времени ответа сервера"
      end
    else
      "Рекомендуется продолжить мониторинг данной метрики"
    end
  end

  def generate_performance_recommendation(metric_name, feature_importance)
    most_important_feature = feature_importance.max_by { |_, value| value }
    feature_index = most_important_feature[0].to_i
    
    case metric_name
    when "cpu_usage"
      feature_index == 0 ?
        "Для оптимизации использования CPU рекомендуется управлять потреблением памяти" :
        "Для оптимизации использования CPU рекомендуется оптимизировать обработку запросов"
    when "memory_usage_bytes"
      feature_index == 0 ?
        "Для оптимизации использования памяти рекомендуется контролировать количество активных пользователей" :
        "Для оптимизации использования памяти рекомендуется оптимизировать обработку запросов"
    when "http_request_duration_seconds"
      case feature_index
      when 0
        "Для оптимизации времени ответа рекомендуется уменьшить нагрузку на CPU"
      when 1
        "Для оптимизации времени ответа рекомендуется оптимизировать использование памяти"
      when 2
        "Для оптимизации времени ответа рекомендуется более эффективно балансировать входящие запросы"
      end
    else
      "Рекомендуется регулярный мониторинг и анализ метрики"
    end
  end

  # Вспомогательный метод для получения данных для производительности
  def fetch_performance_data(metric, start_time, end_time)
    data = fetch_metric_data(metric, start_time, end_time)
    
    # Добавляем меткы времени
    data[:start_time] = start_time
    data[:end_time] = end_time
    
    data
  end
end