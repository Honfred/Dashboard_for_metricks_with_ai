class DashboardController < ApplicationController
  def index
    begin
      @metrics = fetch_metrics
      @settings = user_dashboard_settings
    rescue => e
      Rails.logger.error("Error in dashboard index: #{e.message}")
      flash.now[:alert] = "Проблема с загрузкой метрик. Попробуйте обновить страницу позже."
      @metrics = []
      @settings = default_settings
    end
  end

  def ai_overview
    # Получаем статистику по всем типам ИИ-анализа
    @anomaly_analyses_count = AiAnalysis.where(analysis_type: 'anomaly_detection', status: 'completed').count
    @trend_analyses_count = AiAnalysis.where(analysis_type: 'trend_prediction', status: 'completed').count
    @performance_analyses_count = AiAnalysis.where(analysis_type: 'performance_insight', status: 'completed').count
    
    # Получаем последние завершенные анализы каждого типа для графиков
    @recent_anomalies = AiAnalysis.where(analysis_type: 'anomaly_detection', status: 'completed')
                                 .includes(:metric)
                                 .order(created_at: :desc)
                                 .limit(5)
    
    @recent_trends = AiAnalysis.where(analysis_type: 'trend_prediction', status: 'completed')
                              .includes(:metric)
                              .order(created_at: :desc)
                              .limit(5)
                              
    @recent_performances = AiAnalysis.where(analysis_type: 'performance_insight', status: 'completed')
                                    .includes(:metric)
                                    .order(created_at: :desc)
                                    .limit(5)
                                    
    # Подготовка данных для графиков
    @anomaly_chart_data = prepare_anomaly_chart_data(@recent_anomalies)
    @trend_chart_data = prepare_trend_chart_data(@recent_trends)
  end

  # API эндпоинт для получения метрик
  def metrics
    begin
      time_range = params[:time_range] || user_dashboard_settings[:time_range] || "1h"
      metrics_data = fetch_metrics_for_range(time_range)
      
      render json: metrics_data
    rescue => e
      Rails.logger.error("Error fetching metrics API: #{e.message}")
      render json: { error: "Не удалось получить метрики. Пожалуйста, попробуйте позже." }, status: :service_unavailable
    end
  end

  # API эндпоинт для сохранения настроек дашборда
  def save_settings
    begin
      settings_data = params.require(:settings).permit!.to_h
      
      # Сохраняем настройки в базе данных
      dashboard_setting = DashboardSetting.current('default')
      dashboard_setting.update(settings: settings_data)
      
      respond_to do |format|
        format.json { render json: { success: true, settings: dashboard_setting.merged_settings } }
      end
    rescue => e
      Rails.logger.error("Error saving dashboard settings: #{e.message}")
      respond_to do |format|
        format.json { render json: { success: false, error: "Не удалось сохранить настройки" }, status: :unprocessable_entity }
      end
    end
  end

  # API эндпоинт для получения настроек дашборда
  def settings
    begin
      settings = user_dashboard_settings
      
      render json: { success: true, settings: settings }
    rescue => e
      Rails.logger.error("Error fetching dashboard settings API: #{e.message}")
      render json: { success: false, error: "Не удалось получить настройки. Пожалуйста, попробуйте позже." }, status: :service_unavailable
    end
  end

  private

  def default_settings
    {
      time_range: "1h",
      refresh_interval: 60,
      displayed_panels: ["services_status", "response_time", "throughput", "error_rate", "resource_usage"]
    }
  end

  def user_dashboard_settings
    # Получаем настройки из базы данных или используем настройки по умолчанию
    begin
      DashboardSetting.current('default').merged_settings
    rescue => e
      Rails.logger.error("Error loading dashboard settings: #{e.message}")
      default_settings
    end
  end

  def fetch_metrics
    Rails.cache.fetch("prometheus_metrics", expires_in: 30.seconds) do
      PrometheusClient.new.fetch_metrics
    end
  rescue => e
    Rails.logger.error("Error in fetch_metrics: #{e.message}")
    { "error" => e.message }
  end

  def fetch_metrics_for_range(time_range)
    cache_key = "prometheus_metrics_range_#{time_range}"
    cache_expiration = calculate_cache_expiration(time_range)
    
    Rails.cache.fetch(cache_key, expires_in: cache_expiration) do
      client = PrometheusClient.new
      end_time = Time.now
      start_time = calculate_start_time(end_time, time_range)
      step = calculate_step(time_range)

      {
        services_status: fetch_services_status(client),
        response_time: fetch_response_time(client, start_time, end_time, step),
        throughput: fetch_throughput(client, start_time, end_time, step),
        error_rate: fetch_error_rate(client, start_time, end_time, step),
        resource_usage: fetch_resource_usage(client, start_time, end_time, step)
      }
    end
  rescue => e
    Rails.logger.error("Error in fetch_metrics_for_range: #{e.message}")
    { error: e.message }
  end

  def calculate_cache_expiration(time_range)
    case time_range
    when "15m" then 15.seconds
    when "1h" then 30.seconds
    when "3h" then 1.minute
    when "6h" then 2.minutes
    when "12h" then 3.minutes
    when "24h" then 5.minutes
    when "7d" then 10.minutes
    else 30.seconds
    end
  end

  def fetch_services_status(client)
    result = client.fetch_metrics("up")
    parse_status_results(result)
  rescue => e
    Rails.logger.error("Error fetching service status: #{e.message}")
    []
  end

  def fetch_response_time(client, start_time, end_time, step)
    result = client.fetch_range_metrics("http_request_duration_seconds", start_time, end_time, step)
    parse_time_series(result)
  rescue => e
    Rails.logger.error("Error fetching response time: #{e.message}")
    []
  end

  def fetch_throughput(client, start_time, end_time, step)
    result = client.fetch_range_metrics("rate(http_requests_total[1m])", start_time, end_time, step)
    parse_time_series(result)
  rescue => e
    Rails.logger.error("Error fetching throughput: #{e.message}")
    []
  end

  def fetch_error_rate(client, start_time, end_time, step)
    result = client.fetch_range_metrics('rate(http_requests_total{status=~"5.."}[1m]) / rate(http_requests_total[1m])', start_time, end_time, step)
    parse_time_series(result)
  rescue => e
    Rails.logger.error("Error fetching error rate: #{e.message}")
    []
  end

  def fetch_resource_usage(client, start_time, end_time, step)
    cpu_result = client.fetch_range_metrics("process_cpu_seconds_total", start_time, end_time, step)
    memory_result = client.fetch_range_metrics("process_resident_memory_bytes", start_time, end_time, step)

    {
      cpu: parse_time_series(cpu_result),
      memory: parse_time_series(memory_result)
    }
  rescue => e
    Rails.logger.error("Error fetching resource usage: #{e.message}")
    { cpu: [], memory: [] }
  end

  def parse_status_results(result)
    return [] unless result["data"] && result["data"]["result"]

    result["data"]["result"].map do |item|
      {
        name: item["metric"]["instance"] || item["metric"]["job"],
        status: item["value"][1] == "1"
      }
    end
  end

  def parse_time_series(result)
    return [] unless result["data"] && result["data"]["result"]

    result["data"]["result"].map do |series|
      {
        metric: series["metric"],
        values: series["values"].map { |time, value| [ time * 1000, value.to_f ] }
      }
    end
  end

  def calculate_start_time(end_time, time_range)
    case time_range
    when "15m" then end_time - 15.minutes
    when "1h" then end_time - 1.hour
    when "3h" then end_time - 3.hours
    when "6h" then end_time - 6.hours
    when "12h" then end_time - 12.hours
    when "24h" then end_time - 24.hours
    when "7d" then end_time - 7.days
    else end_time - 1.hour
    end
  end

  def calculate_step(time_range)
    case time_range
    when "15m" then "15s"
    when "1h" then "30s"
    when "3h" then "1m"
    when "6h" then "2m"
    when "12h" then "5m"
    when "24h" then "10m"
    when "7d" then "1h"
    else "30s"
    end
  end

  def prepare_anomaly_chart_data(analyses)
    analyses.map do |analysis|
      next unless analysis.report.present? && analysis.report["events"].present?
      
      events = analysis.report["events"].take(10)
      {
        metric_name: analysis.metric.name,
        timestamps: events.map { |e| Time.at(e["timestamp"]).strftime("%d.%m %H:%M") },
        values: events.map { |e| e["value"] },
        deviations: events.map { |e| e["deviation"] }
      }
    end.compact
  end
  
  def prepare_trend_chart_data(analyses)
    analyses.map do |analysis|
      next unless analysis.report.present? && analysis.report["events"].present?
      
      events = analysis.report["events"].take(10)
      {
        metric_name: analysis.metric.name,
        timestamps: events.map { |e| Time.at(e["timestamp"]).strftime("%d.%м %H:%M") },
        values: events.map { |e| e["value"] }
      }
    end.compact
  end
end
