require "net/http"
require "json"

class AiService
  attr_reader :base_url

  def initialize
    @base_url = Rails.configuration.ai_service_url || "http://localhost:5000"
  end

  def fetch_analysis(metric_id, analysis_type = "anomaly_detection")
    cache_key = "ai_analysis:#{metric_id}:#{analysis_type}"

    cached = Rails.cache.read(cache_key)
    return cached if cached

    begin
      uri = URI("#{@base_url}/api/#{analysis_type}")

      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      request.body = { metric_id: metric_id }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        Rails.cache.write(cache_key, result, expires_in: 10.minutes)
        return result
      end

      Rails.logger.error "AI Service error: #{response.message}"
      { "status" => "error", "error" => response.message, "message" => "Сервис AI временно недоступен" }
    rescue => e
      Rails.logger.error "Error connecting to AI Service: #{e.message}"
      { "status" => "error", "error" => e.message, "message" => "Не удалось подключиться к сервису AI" }
    end
  end

  def available_analysis_types
    begin
      uri = URI("#{@base_url}/api/analysis_types")
      response = Net::HTTP.get_response(uri)

      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      Rails.logger.error "AI Service error: #{response.message}"
      { "types" => [ "anomaly_detection", "trend_prediction", "performance_insight" ] }
    rescue => e
      Rails.logger.error "Error connecting to AI Service: #{e.message}"
      { "types" => [ "anomaly_detection", "trend_prediction", "performance_insight" ] }
    end
  end
end
