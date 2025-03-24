class DashboardController < ApplicationController
  def index
    @metrics = fetch_metrics
  end

  # API эндпоинт для получения метрик
  def metrics
    time_range = params[:time_range] || "1h"
    metrics_data = fetch_metrics_for_range(time_range)

    render json: metrics_data
  end

  private

  def fetch_metrics
    PrometheusClient.new.fetch_metrics
  end

  def fetch_metrics_for_range(time_range)
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

  def fetch_services_status(client)
    result = client.fetch_metrics("up")
    parse_status_results(result)
  end

  def fetch_response_time(client, start_time, end_time, step)
    result = client.fetch_range_metrics("http_request_duration_seconds", start_time, end_time, step)
    parse_time_series(result)
  end

  def fetch_throughput(client, start_time, end_time, step)
    result = client.fetch_range_metrics("rate(http_requests_total[1m])", start_time, end_time, step)
    parse_time_series(result)
  end

  def fetch_error_rate(client, start_time, end_time, step)
    result = client.fetch_range_metrics('rate(http_requests_total{status=~"5.."}[1m]) / rate(http_requests_total[1m])', start_time, end_time, step)
    parse_time_series(result)
  end

  def fetch_resource_usage(client, start_time, end_time, step)
    cpu_result = client.fetch_range_metrics("process_cpu_seconds_total", start_time, end_time, step)
    memory_result = client.fetch_range_metrics("process_resident_memory_bytes", start_time, end_time, step)

    {
      cpu: parse_time_series(cpu_result),
      memory: parse_time_series(memory_result)
    }
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
end
