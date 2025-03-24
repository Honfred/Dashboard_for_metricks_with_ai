require "net/http"
require "json"

class PrometheusService
  attr_reader :base_url

  def initialize
    @base_url = Rails.application.config.prometheus_url || "http://localhost:9090"
  end

  def fetch_metrics(service_name, time_range = "1h")
    query = "rate(#{service_name}_requests_total[#{time_range}])"
    response = query_prometheus(query)
    parse_response(response)
  end

  def available_metrics
    # Получаем информацию о targets (активные и неактивные источники данных)
    targets_response = query_prometheus_api("targets")
    
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
end
