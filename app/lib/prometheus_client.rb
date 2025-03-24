require "net/http"
require "uri"
require "json"

class PrometheusClient
  PROMETHEUS_URL = ENV["PROMETHEUS_URL"] || "http://prometheus:9090"

  def fetch_metrics(query = "up", time = Time.now)
    response = query_prometheus(query, time)
    parse_response(response)
  end

  def fetch_range_metrics(query, start_time, end_time, step = "1m")
    response = query_prometheus_range(query, start_time, end_time, step)
    parse_response(response)
  end

  def available_metrics
    response = query_prometheus_labels
    parse_response(response)
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
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)

    response = http.request(request)
    response.body
  end

  def parse_response(response)
    JSON.parse(response)
  rescue JSON::ParserError => e
    Rails.logger.error("Error parsing Prometheus response: #{e.message}")
    { "error" => "Failed to parse Prometheus response" }
  end
end
