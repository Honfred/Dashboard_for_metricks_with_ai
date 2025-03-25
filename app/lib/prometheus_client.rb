require "net/http"
require "uri"
require "json"

class PrometheusClient
  PROMETHEUS_URL = ENV["PROMETHEUS_URL"] || "http://prometheus:9090"
  REQUEST_TIMEOUT = 5 # 5 секунд таймаут

  def fetch_metrics(query = "up", time = Time.now)
    response = query_prometheus(query, time)
    parse_response(response)
  rescue => e
    Rails.logger.error("Error fetching metrics: #{e.message}")
    { "error" => "Failed to fetch metrics: #{e.message}" }
  end

  def fetch_range_metrics(query, start_time, end_time, step = "1m")
    response = query_prometheus_range(query, start_time, end_time, step)
    parse_response(response)
  rescue => e
    Rails.logger.error("Error fetching range metrics: #{e.message}")
    { "error" => "Failed to fetch range metrics: #{e.message}" }
  end

  def available_metrics
    response = query_prometheus_labels
    parse_response(response)
  rescue => e
    Rails.logger.error("Error fetching available metrics: #{e.message}")
    { "error" => "Failed to fetch available metrics: #{e.message}" }
  end

  private

  def query_prometheus(query, time)
    uri = URI.parse("#{PROMETHEUS_URL}/api/v1/query")
    params = { query: query, time: time.to_i }
    uri.query = URI.encode_www_form(params)

    make_request(uri)
  end

  def query_prometheus_range(query, start_time, end_time, step)
    uri = URI.parse("#{PROMETHEUS_URL}/api/v1/query_range")
    params = {
      query: query,
      start: start_time.to_i,
      end: end_time.to_i,
      step: step
    }
    uri.query = URI.encode_www_form(params)

    make_request(uri)
  end

  def query_prometheus_labels
    uri = URI.parse("#{PROMETHEUS_URL}/api/v1/labels")
    make_request(uri)
  end

  def make_request(uri)
    Rails.logger.debug("Making request to Prometheus: #{uri}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = REQUEST_TIMEOUT
    http.read_timeout = REQUEST_TIMEOUT
    request = Net::HTTP::Get.new(uri.request_uri)

    begin
      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("Prometheus API returned status #{response.code}: #{response.message}")
        raise "Prometheus API returned status #{response.code}: #{response.message}"
      end
      response.body
    rescue => e
      Rails.logger.error("Error connecting to Prometheus API: #{e.message}")
      raise "Failed to connect to Prometheus API: #{e.message}"
    end
  end

  def parse_response(response)
    JSON.parse(response)
  rescue JSON::ParserError => e
    Rails.logger.error("Error parsing Prometheus response: #{e.message}")
    { "error" => "Failed to parse Prometheus response: #{e.message}" }
  end
end
