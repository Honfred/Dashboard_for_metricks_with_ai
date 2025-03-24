require "net/http"
require "json"

class PrometheusService
  attr_reader :base_url

  def initialize
    @base_url = Rails.application.config.prometheus_url || "http://localhost:9090"
  end

  def fetch_metrics(service_name, time_range = "1h")
    # Попытка получить данные из Prometheus
    query = generate_metric_query(service_name, time_range)
    response = query_prometheus(query)
    
    # Если получили данные - отлично, возвращаем их
    parsed_data = parse_response(response)
    return parsed_data if parsed_data.present?
    
    # Если данных нет, генерируем демо-данные для примера
    generate_demo_metrics(service_name, time_range)
  end

  def available_metrics
    # Получаем информацию о targets (активные и неактивные источники данных)
    targets_response = query_prometheus_api("targets")
    
    # Проверяем ответ от Prometheus
    if targets_response["status"] != "success" || !targets_response.dig("data", "activeTargets")
      # Если не удалось получить реальные данные, создаем демонстрационные
      return generate_demo_targets
    end
    
    # Получаем метрики up для статуса активности
    up_response = query_prometheus("up")
    
    # Объединяем данные для полной картины
    active_targets = parse_active_targets(up_response)
    all_targets = parse_target_info(targets_response)
    
    # Логируем информацию для отладки
    Rails.logger.info "Active targets: #{active_targets.inspect}"
    Rails.logger.info "All targets: #{all_targets.inspect}"
    
    # Добавляем статусы из up_response к all_targets
    merged_targets = merge_target_data(all_targets, active_targets)
    
    # Логируем результат
    Rails.logger.info "Merged targets: #{merged_targets.inspect}"
    
    # Если список пуст, добавляем демо-источники
    return generate_demo_targets if merged_targets.empty?
    
    merged_targets
  end

  private

  def query_prometheus(query)
    uri = URI("#{@base_url}/api/v1/query")
    uri.query = URI.encode_www_form(query: query)
    
    begin
      response = Net::HTTP.get_response(uri)
      
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      
      Rails.logger.error "Prometheus error: #{response.message}"
      { "status" => "error", "error" => response.message }
    rescue => e
      Rails.logger.error "Error connecting to Prometheus: #{e.message}"
      { "status" => "error", "error" => e.message }
    end
  end

  def query_prometheus_api(endpoint)
    uri = URI("#{@base_url}/api/v1/#{endpoint}")
    
    begin
      response = Net::HTTP.get_response(uri)
      
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      
      Rails.logger.error "Prometheus API error: #{response.message}"
      { "status" => "error", "error" => response.message }
    rescue => e
      Rails.logger.error "Error connecting to Prometheus API: #{e.message}"
      { "status" => "error", "error" => e.message }
    end
  end

  def parse_response(response)
    return [] unless response["status"] == "success"
    return [] if response["data"]["result"].empty?

    response["data"]["result"].map do |result|
      {
        metric: result["metric"],
        values: result["values"] || [ [ result["value"][0], result["value"][1] ] ]
      }
    end
  end
  
  def parse_active_targets(response)
    return [] unless response["status"] == "success"
    return [] if response["data"]["result"].empty?

    response["data"]["result"]
      .map do |result|
        {
          instance: result["metric"]["instance"] || "unknown",
          job: result["metric"]["job"] || result["metric"]["service"] || "unknown",
          active: result["value"][1] == "1"
        }
      end
  end
  
  def parse_target_info(response)
    return [] unless response["status"] == "success"
    
    # Получаем все активные и неактивные цели
    active_targets = response.dig("data", "activeTargets") || []
    
    # Фильтруем местный источник (web:3000) из списка
    filtered_targets = active_targets.reject do |target|
      target["instance"] == "web:3000" || 
      target["instance"] == "localhost:3000" || 
      target["labels"]["instance"] == "web:3000" || 
      target["labels"]["instance"] == "localhost:3000"
    end
    
    filtered_targets.map do |target|
      {
        instance: target["labels"]["instance"] || target["instance"],
        job: target["labels"]["job"] || target["job"],
        health: target["health"],
        last_update: Time.parse(target["lastScrape"]),
        last_scrape: target["lastScrape"],
        last_error: target["lastError"],
        scrape_url: target["scrapeUrl"],
        labels: target["labels"] || {}
      }
    end
  end
  
  def merge_target_data(target_info, active_info)
    # Создаем хэш для быстрого поиска активности по instance и job
    active_map = {}
    active_info.each do |item|
      key = "#{item[:instance]}_#{item[:job]}"
      active_map[key] = item[:active]
    end
    
    # Дополняем данные о target'ах данными о активности
    target_info.map do |target|
      key = "#{target[:instance]}_#{target[:job]}"
      target[:active] = active_map[key] || (target[:health] == "up")
      target
    end
  end

  # Генерирует подходящий запрос в зависимости от типа метрики
  def generate_metric_query(metric_name, time_range)
    # Проверяем, существует ли такая метрика в системе
    metric = Metric.find_by(name: metric_name)
    
    if metric.nil?
      return "#{metric_name}"
    end
    
    case metric.metric_type
    when "counter"
      "rate(#{metric_name}[#{time_range}])"
    when "gauge"
      "#{metric_name}"
    when "histogram"
      "histogram_quantile(0.95, sum(rate(#{metric_name}_bucket[#{time_range}])) by (le))"
    when "summary"
      "#{metric_name}_sum / #{metric_name}_count"
    else
      "#{metric_name}"
    end
  end
  
  # Генерирует демонстрационные данные для примера
  def generate_demo_metrics(metric_name, time_range)
    # Находим метрику в базе данных
    metric = Metric.find_by(name: metric_name)
    return [] unless metric
    
    # Определяем временные параметры
    end_time = Time.now.to_i
    
    case time_range
    when "1h"
      start_time = end_time - 3600
      step = 60
    when "6h"
      start_time = end_time - 21600
      step = 300
    when "24h"
      start_time = end_time - 86400
      step = 1200
    when "7d"
      start_time = end_time - 604800
      step = 3600
    else
      start_time = end_time - 3600
      step = 60
    end
    
    # Генерируем демо-данные в зависимости от типа метрики
    values = []
    current_time = start_time
    
    # Параметры для создания реалистичных данных
    base_value = rand(10..100).to_f
    trend = rand(-0.5..0.5)
    variation = rand(1..10)
    
    # Генерируем временной ряд с данными
    while current_time <= end_time
      case metric.metric_type
      when "counter"
        # Для счетчиков создаем растущую линию с небольшими колебаниями
        value = base_value + ((current_time - start_time) * 0.01) + rand(-variation..variation)
      when "gauge"
        # Для датчиков создаем линию с более выраженными колебаниями
        value = base_value + ((current_time - start_time) * trend * 0.001) + rand(-variation*2..variation*2)
      when "histogram", "summary"
        # Для распределений и сводок создаем линию с периодическими колебаниями
        cycle = Math.sin((current_time - start_time) / 1800.0) * variation
        value = base_value + cycle + rand(-variation/2..variation/2)
      else
        value = base_value + rand(-variation..variation)
      end
      
      # Убеждаемся, что значение не отрицательное
      value = value.abs
      
      # Форматируем значение для красивого вывода
      formatted_value = "%.2f" % value
      
      # Добавляем точку в временной ряд
      values << [current_time, formatted_value]
      
      # Переходим к следующей временной точке
      current_time += step
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

  # Создает демонстрационные источники данных для Prometheus
  def generate_demo_targets
    demo_targets = [
      {
        instance: "prometheus:9090",
        job: "prometheus",
        health: "up",
        active: true,
        last_scrape: Time.now.utc.iso8601,
        scrape_url: "http://prometheus:9090/metrics",
        labels: { "env" => "production", "region" => "eu-west" }
      },
      {
        instance: "node-exporter:9100",
        job: "node",
        health: "up",
        active: true,
        last_scrape: Time.now.utc.iso8601,
        scrape_url: "http://node-exporter:9100/metrics",
        labels: { "env" => "production", "region" => "eu-west" }
      },
      {
        instance: "web:9091",
        job: "rails-app",
        health: "up",
        active: true,
        last_scrape: Time.now.utc.iso8601,
        scrape_url: "http://web:9091/metrics",
        labels: { "env" => "production", "region" => "eu-west" }
      },
      {
        instance: "db-exporter:9187",
        job: "postgresql",
        health: "up",
        active: true,
        last_scrape: Time.now.utc.iso8601,
        scrape_url: "http://db-exporter:9187/metrics",
        labels: { "env" => "production", "region" => "eu-west" }
      },
      {
        instance: "redis-exporter:9121",
        job: "redis",
        health: "up",
        active: true,
        last_scrape: Time.now.utc.iso8601,
        scrape_url: "http://redis-exporter:9121/metrics",
        labels: { "env" => "production", "region" => "eu-west" }
      },
      {
        instance: "worker:9092",
        job: "sidekiq",
        health: "up",
        active: true,
        last_scrape: Time.now.utc.iso8601,
        scrape_url: "http://worker:9092/metrics",
        labels: { "env" => "production", "region" => "eu-west" }
      }
    ]
    
    # Для разнообразия добавляем один неактивный источник
    demo_targets << {
      instance: "staging-app:9091",
      job: "rails-app",
      health: "down",
      active: false,
      last_scrape: (Time.now - 2.hours).utc.iso8601,
      scrape_url: "http://staging-app:9091/metrics",
      labels: { "env" => "staging", "region" => "eu-west" }
    }
    
    demo_targets
  end
end
