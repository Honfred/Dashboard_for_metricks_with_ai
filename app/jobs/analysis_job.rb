class AnalysisJob < ApplicationJob
  include MetricDataFetchable
  queue_as :ml
  retry_on StandardError, wait: 5.seconds, attempts: 3, queue: :ml

  def perform(ai_analysis_id, locale = 'en')
    # Устанавливаем локаль для переводов в job
    I18n.locale = locale.to_sym
    
    Rails.logger.info("AnalysisJob: Starting analysis for ID: #{ai_analysis_id} with locale: #{locale}")
    
    ai_analysis = AiAnalysis.find_by(id: ai_analysis_id)
    unless ai_analysis
      Rails.logger.error("AnalysisJob: Analysis with ID #{ai_analysis_id} not found")
      return
    end
    
    # Добавляем защиту от повторного запуска для уже завершенного анализа
    if ai_analysis.completed? || ai_analysis.failed?
      Rails.logger.info("AnalysisJob: Analysis #{ai_analysis_id} is already #{ai_analysis.status}, skipping")
      return
    end
    
    # Обновляем статус на "processing"
    ai_analysis.update(status: 'processing')
    Rails.logger.info("AnalysisJob: Analysis status set to 'processing'")
    
    metric = ai_analysis.metric

    # Получаем данные метрики за соответствующий период
    data = case ai_analysis.analysis_type
      when 'anomaly_detection'
        fetch_metric_data(metric, 1.week.ago, Time.now)
      when 'trend_prediction'
        # Для тренда получаем все серии
        { all_series: fetch_all_metric_series(metric, 1.day.ago, Time.now, step: '5m') }
      when 'performance_insight'
        fetch_performance_data(metric, 1.day.ago, Time.now, step: '5m')
    end

    # Проверка данных
    if ai_analysis.analysis_type == 'trend_prediction'
      if data[:all_series].blank?
        Rails.logger.error("AnalysisJob: No series found for metric #{metric.name}")
        ai_analysis.update(
          status: 'failed',
          results: { "status" => "error", "message" => I18n.t('ai_analysis.report.errors.no_data') },
          completed_at: Time.current
        )
        return
      end
      Rails.logger.info("AnalysisJob: Got #{data[:all_series].size} series for trend analysis")
    elsif data[:values].blank?
      Rails.logger.error("AnalysisJob: No data found for metric #{metric.name}")
      ai_analysis.update(
        status: 'failed',
        results: { "status" => "error", "message" => I18n.t('ai_analysis.report.errors.no_data') },
        completed_at: Time.current
      )
      return
    else
      Rails.logger.info("AnalysisJob: Got #{data[:values].size} data points for analysis")
    end

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
        results: { "status" => "error", "message" => I18n.t('ai_analysis.report.errors.analysis_error') + ": #{e.message}" },
        completed_at: Time.current
      )
    end
    
    Rails.logger.info("AnalysisJob: Analysis completed with status #{ai_analysis.status}")
  end

  private

  # Обнаружение аномалий
  def detect_anomalies(metric_name, data)
    result = MlService.detect_anomalies(metric_name, data[:values], data[:timestamps])
    
    # Добавляем исходные данные для построения графика
    if result["status"] == "success"
      result["timestamps"] = data[:timestamps]
      result["values"] = data[:values]
    end
    
    result
  end

  # Прогнозирование трендов для всех серий
  def predict_trend(metric_name, data)
    all_series = data[:all_series]
    
    series_results = []
    
    all_series.each do |series|
      next if series[:values].blank? || series[:values].size < 2
      
      # Получаем прогноз для каждой серии
      result = MlService.predict_trend(
        metric_name, 
        24,  # Прогноз на 24 часа вперед
        values: series[:values],
        timestamps: series[:timestamps]
      )
      
      if result["status"] == "success"
        series_results << {
          label: series[:label],
          labels: series[:labels],
          current_data: {
            timestamps: series[:timestamps],
            values: series[:values]
          },
          prediction: result["prediction"]
        }
      end
    end
    
    if series_results.empty?
      return { "status" => "error", "message" => I18n.t('ai_analysis.report.errors.no_data') }
    end
    
    {
      "status" => "success",
      "series" => series_results
    }
  end

  # Анализ производительности
  def analyze_performance(metric_name, data)
    # Для анализа производительности используем текущие данные метрики как признаки
    # Это упрощённый подход - в реальном приложении можно собирать связанные метрики
    
    return { "status" => "error", "message" => I18n.t('ai_analysis.report.errors.insufficient_data') } if data[:values].blank? || data[:values].size < 3
    
    # Формируем признаки из самих данных метрики
    # Используем скользящее окно для создания признаков
    values = data[:values]
    features = []
    
    # Создаём признаки: [текущее значение, среднее за последние 3 точки, макс за последние 3 точки]
    (2...values.size).each do |i|
      window = values[(i-2)..i]
      features << [
        values[i],
        window.sum / window.size.to_f,
        window.max
      ]
    end
    
    return { "status" => "error", "message" => I18n.t('ai_analysis.report.errors.insufficient_data') } if features.blank?
    
    # Для ML-анализа нам нужна обученная модель, но пока сделаем простой статистический анализ
    result = perform_simple_performance_analysis(metric_name, data)
    result
  end
  
  # Простой статистический анализ производительности
  def perform_simple_performance_analysis(metric_name, data)
    values = data[:values]
    timestamps = data[:timestamps]
    
    mean_val = values.sum / values.size.to_f
    std_val = Math.sqrt(values.map { |v| (v - mean_val) ** 2 }.sum / values.size)
    min_val = values.min
    max_val = values.max
    
    # Определяем тренд
    first_half_avg = values[0...(values.size/2)].sum / (values.size/2).to_f
    second_half_avg = values[(values.size/2)..].sum / (values.size - values.size/2).to_f
    trend = second_half_avg > first_half_avg ? "increasing" : (second_half_avg < first_half_avg ? "decreasing" : "stable")
    
    # Находим выбросы (значения > 2 стандартных отклонения)
    threshold = mean_val + 2 * std_val
    outliers = []
    values.each_with_index do |v, i|
      if v > threshold
        outliers << { timestamp: timestamps[i], value: v, deviation: ((v - mean_val) / std_val).round(2) }
      end
    end
    
    {
      "status" => "success",
      "statistics" => {
        "mean" => mean_val.round(4),
        "std" => std_val.round(4),
        "min" => min_val.round(4),
        "max" => max_val.round(4),
        "trend" => trend
      },
      "outliers" => outliers.first(10), # Максимум 10 выбросов
      "predictions" => [mean_val.round(4)], # Простой прогноз на основе среднего
      "feature_importance" => {
        "current_value" => 0.5,
        "moving_average" => 0.3,
        "max_in_window" => 0.2
      },
      "current_data" => {
        "timestamps" => timestamps,
        "values" => values
      }
    }
  end

  # Генерация отчета по анализу
  def generate_analysis_report(ai_analysis, result)
    report = {
      insights: [],
      statistics: {},
      events: [],
      chart_data: {}
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
      I18n.t('ai_analysis.report.statistics.total_data_points') => total_points,
      I18n.t('ai_analysis.report.statistics.anomalies_detected') => anomalies_count,
      I18n.t('ai_analysis.report.statistics.anomaly_percentage') => "#{anomaly_rate}%"
    }
    
    # Выводы ИИ
    if anomalies_count > 0
      severity = case
        when anomaly_rate >= 15 then "high"
        when anomaly_rate >= 5 then "medium"
        else "low"
      end
      
      report[:insights] << {
        "title" => I18n.t('ai_analysis.report.insights.anomalies_found', metric: metric.name),
        "description" => I18n.t('ai_analysis.report.insights.anomalies_description', count: anomalies_count, rate: anomaly_rate),
        "severity" => severity,
        "recommendation" => generate_recommendation_for_metric(metric, severity)
      }
      
      # Выявление паттернов аномалий
      if anomalies_count >= 3
        time_patterns = detect_time_patterns(result["anomalies"])
        if time_patterns
          report[:insights] << {
            "title" => I18n.t('ai_analysis.report.insights.time_pattern'),
            "description" => "#{time_patterns}",
            "severity" => "medium",
            "recommendation" => I18n.t('ai_analysis.report.insights.time_pattern_recommendation')
          }
        end
      end
    else
      report[:insights] << {
        "title" => I18n.t('ai_analysis.report.insights.no_anomalies'),
        "description" => I18n.t('ai_analysis.report.insights.metric_normal', metric: metric.name),
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
        "description" => I18n.t('ai_analysis.report.events.anomaly_value', metric: metric.name)
      }
    end
    
    # Данные для графика
    report[:chart_data] = {
      "timestamps" => result["timestamps"] || [],
      "values" => result["values"] || [],
      "anomalies" => result["anomalies"].map { |a| 
        { 
          "timestamp" => a["timestamp"], 
          "value" => a["value"].is_a?(Array) ? a["value"].first : a["value"] 
        } 
      }
    }
  end

  # Генерация отчета для трендов
  def generate_trend_report(report, result, metric)
    series_data = result["series"] || []
    
    # Если нет серий, используем старый формат (обратная совместимость)
    if series_data.empty? && result["prediction"]
      series_data = [{
        label: metric.name,
        current_data: result["current_data"] || {},
        prediction: result["prediction"] || []
      }]
    end
    
    # Подготавливаем данные для каждой серии
    all_series_chart_data = []
    total_trend_percentage = 0
    
    series_data.each do |series|
      current_data = series[:current_data] || series["current_data"] || {}
      predictions = series[:prediction] || series["prediction"] || []
      current_values = current_data[:values] || current_data["values"] || []
      current_timestamps = current_data[:timestamps] || current_data["timestamps"] || []
      label = series[:label] || series["label"] || "unknown"
      
      next if current_values.empty? || predictions.empty?
      
      last_value = current_values.last
      predicted_values = predictions.map { |p| p["value"] || p[:value] }
      average_prediction = predicted_values.sum / predicted_values.size rescue 0
      trend_percentage = last_value && last_value != 0 ? ((average_prediction - last_value) / last_value * 100).round(2) : 0
      
      total_trend_percentage += trend_percentage
      
      all_series_chart_data << {
        "label" => label,
        "current_timestamps" => current_timestamps,
        "current_values" => current_values,
        "prediction_timestamps" => predictions.map { |p| p["timestamp"] || p[:timestamp] },
        "prediction_values" => predicted_values,
        "trend_percentage" => trend_percentage
      }
    end
    
    avg_trend_percentage = all_series_chart_data.empty? ? 0 : (total_trend_percentage / all_series_chart_data.size).round(2)
    
    # Статистика (усреднённая по всем сериям)
    report[:statistics] = {
      I18n.t('ai_analysis.report.statistics.series_count') => all_series_chart_data.size,
      I18n.t('ai_analysis.report.statistics.average_change') => "#{avg_trend_percentage > 0 ? '+' : ''}#{avg_trend_percentage}%"
    }
    
    # Выводы ИИ
    trend_direction = case
      when avg_trend_percentage >= 10 then I18n.t('ai_analysis.report.trend_directions.significant_growth')
      when avg_trend_percentage > 0 then I18n.t('ai_analysis.report.trend_directions.moderate_growth')
      when avg_trend_percentage == 0 then I18n.t('ai_analysis.report.trend_directions.stable')
      when avg_trend_percentage >= -10 then I18n.t('ai_analysis.report.trend_directions.moderate_decline')
      else I18n.t('ai_analysis.report.trend_directions.significant_decline')
    end
    
    severity = case
      when avg_trend_percentage.abs >= 20 then "high"
      when avg_trend_percentage.abs >= 5 then "medium"
      else "low"
    end
    
    report[:insights] << {
      "title" => I18n.t('ai_analysis.report.insights.trend_forecast', metric: metric.name, direction: trend_direction),
      "description" => I18n.t('ai_analysis.report.insights.trend_description', percentage: avg_trend_percentage),
      "severity" => severity,
      "recommendation" => avg_trend_percentage >= 20 ? I18n.t('ai_analysis.report.insights.increase_resources') : nil
    }
    
    # Данные для графика - все серии
    report[:chart_data] = {
      "series" => all_series_chart_data
    }
    
    # Для обратной совместимости добавляем первую серию в старом формате
    if all_series_chart_data.any?
      first_series = all_series_chart_data.first
      report[:chart_data]["current_timestamps"] = first_series["current_timestamps"]
      report[:chart_data]["current_values"] = first_series["current_values"]
      report[:chart_data]["prediction_timestamps"] = first_series["prediction_timestamps"]
      report[:chart_data]["prediction_values"] = first_series["prediction_values"]
    end
  end

  # Генерация отчета для производительности
  def generate_performance_report(report, result, metric)
    statistics = result["statistics"] || {}
    outliers = result["outliers"] || []
    feature_importance = result["feature_importance"] || {}
    current_data = result["current_data"] || {}
    
    # Статистика
    report[:statistics] = {
      I18n.t('ai_analysis.report.statistics.mean_value') => statistics["mean"]&.round(4) || 0,
      I18n.t('ai_analysis.report.statistics.std_deviation') => statistics["std"]&.round(4) || 0,
      I18n.t('ai_analysis.report.statistics.min_value') => statistics["min"]&.round(4) || 0,
      I18n.t('ai_analysis.report.statistics.max_value') => statistics["max"]&.round(4) || 0,
      I18n.t('ai_analysis.report.statistics.trend') => statistics["trend"] || "unknown"
    }
    
    # Определяем уровень важности на основе тренда и выбросов
    trend = statistics["trend"]
    severity = if trend == "increasing" && outliers.size > 3
      "high"
    elsif trend == "increasing" || outliers.size > 0
      "medium"
    else
      "low"
    end
    
    # Основной вывод
    trend_text = case trend
      when "increasing" then I18n.t('ai_analysis.report.trends.increasing')
      when "decreasing" then I18n.t('ai_analysis.report.trends.decreasing')
      else I18n.t('ai_analysis.report.trends.stable')
    end
    
    report[:insights] << {
      "title" => I18n.t('ai_analysis.report.insights.performance_title', metric: metric.name),
      "description" => I18n.t('ai_analysis.report.insights.performance_trend_description', trend: trend_text, mean: statistics["mean"]&.round(4)),
      "severity" => severity,
      "recommendation" => generate_performance_recommendation_by_trend(trend, outliers.size)
    }
    
    # Если есть выбросы, добавляем информацию о них
    if outliers.any?
      report[:insights] << {
        "title" => I18n.t('ai_analysis.report.insights.outliers_detected', count: outliers.size),
        "description" => I18n.t('ai_analysis.report.insights.outliers_description', max_deviation: outliers.map { |o| o["deviation"] || 0 }.max.round(2)),
        "severity" => outliers.size > 5 ? "high" : "medium",
        "recommendation" => I18n.t('ai_analysis.report.insights.investigate_outliers')
      }
    end
    
    # События - добавляем выбросы как события
    outliers.first(10).each do |outlier|
      report[:events] << {
        "timestamp" => outlier["timestamp"],
        "type" => "outlier",
        "value" => outlier["value"]&.round(4),
        "deviation" => outlier["deviation"],
        "description" => I18n.t('ai_analysis.report.events.outlier_detected', metric: metric.name)
      }
    end
    
    # Данные для графика
    report[:chart_data] = {
      "current_timestamps" => current_data["timestamps"] || [],
      "current_values" => current_data["values"] || [],
      "outlier_timestamps" => outliers.map { |o| o["timestamp"] },
      "outlier_values" => outliers.map { |o| o["value"] },
      "feature_importance" => feature_importance
    }
  end
  
  def generate_performance_recommendation_by_trend(trend, outliers_count)
    case trend
    when "increasing"
      if outliers_count > 3
        I18n.t('ai_analysis.report.recommendations.urgent_optimization')
      else
        I18n.t('ai_analysis.report.recommendations.monitor_growth')
      end
    when "decreasing"
      I18n.t('ai_analysis.report.recommendations.good_performance')
    else
      if outliers_count > 0
        I18n.t('ai_analysis.report.recommendations.investigate_spikes')
      else
        I18n.t('ai_analysis.report.recommendations.stable_performance')
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
      return I18n.t('ai_analysis.report.insights.peak_hours', hours: peak_hours.join(', '))
    end
    
    # Проверка на день недели
    day_counts = times.group_by { |t| t.wday }.transform_values(&:size)
    max_day_count = day_counts.values.max
    if max_day_count >= anomalies.size * 0.5
      days = I18n.t('ai_analysis.report.days').split(',')
      peak_days = day_counts.select { |_, count| count >= max_day_count * 0.7 }
                          .keys.sort.map { |d| days[d] }
      return I18n.t('ai_analysis.report.insights.peak_days', days: peak_days.join(', '))
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
        I18n.t('ai_analysis.report.recommendations.cpu_high')
      when "medium"
        I18n.t('ai_analysis.report.recommendations.cpu_medium')
      else
        I18n.t('ai_analysis.report.recommendations.cpu_low')
      end
    when "memory_usage_bytes"
      case severity
      when "high"
        I18n.t('ai_analysis.report.recommendations.memory_high')
      when "medium"
        I18n.t('ai_analysis.report.recommendations.memory_medium')
      else
        I18n.t('ai_analysis.report.recommendations.memory_low')
      end
    when "http_request_duration_seconds"
      case severity
      when "high"
        I18n.t('ai_analysis.report.recommendations.http_high')
      when "medium"
        I18n.t('ai_analysis.report.recommendations.http_medium')
      else
        I18n.t('ai_analysis.report.recommendations.http_low')
      end
    else
      I18n.t('ai_analysis.report.recommendations.default')
    end
  end

  def generate_performance_recommendation(metric_name, feature_importance)
    most_important_feature = feature_importance.max_by { |_, value| value }
    feature_index = most_important_feature[0].to_i
    
    case metric_name
    when "cpu_usage"
      feature_index == 0 ?
        I18n.t('ai_analysis.report.recommendations.cpu_perf_memory') :
        I18n.t('ai_analysis.report.recommendations.cpu_perf_requests')
    when "memory_usage_bytes"
      feature_index == 0 ?
        I18n.t('ai_analysis.report.recommendations.memory_perf_users') :
        I18n.t('ai_analysis.report.recommendations.memory_perf_requests')
    when "http_request_duration_seconds"
      case feature_index
      when 0
        I18n.t('ai_analysis.report.recommendations.http_perf_cpu')
      when 1
        I18n.t('ai_analysis.report.recommendations.http_perf_memory')
      when 2
        I18n.t('ai_analysis.report.recommendations.http_perf_balance')
      end
    else
      I18n.t('ai_analysis.report.recommendations.default_perf')
    end
  end

  # Вспомогательный метод для получения данных для производительности
  def fetch_performance_data(metric, start_time, end_time, step: '1h')
    data = fetch_metric_data(metric, start_time, end_time, step: step)
    
    # Добавляем меткы времени
    data[:start_time] = start_time
    data[:end_time] = end_time
    
    data
  end
end