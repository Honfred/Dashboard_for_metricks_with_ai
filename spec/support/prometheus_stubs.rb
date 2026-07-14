# Хелперы для стаба Prometheus API (PrometheusClient и PrometheusService
# ходят на PROMETHEUS_URL / config.prometheus_url)
module PrometheusStubs
  def prometheus_base_urls
    [
      ENV["PROMETHEUS_URL"],
      Rails.application.config.respond_to?(:prometheus_url) ? Rails.application.config.prometheus_url : nil,
      "http://prometheus:9090",
      "http://localhost:9090"
    ].compact.uniq
  end

  # Instant query /api/v1/query
  def stub_prometheus_query(result: default_up_result, status: "success")
    prometheus_base_urls.each do |base|
      stub_request(:get, %r{#{Regexp.escape(base)}/api/v1/query\?.*})
        .to_return(
          status: 200,
          body: { status: status, data: { resultType: "vector", result: result } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end

  # Range query /api/v1/query_range
  def stub_prometheus_range(result: default_range_result, status: "success")
    prometheus_base_urls.each do |base|
      stub_request(:get, %r{#{Regexp.escape(base)}/api/v1/query_range\?.*})
        .to_return(
          status: 200,
          body: { status: status, data: { resultType: "matrix", result: result } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end

  # /api/v1/targets и /api/v1/labels
  def stub_prometheus_meta(targets: default_targets)
    prometheus_base_urls.each do |base|
      stub_request(:get, %r{#{Regexp.escape(base)}/api/v1/targets.*})
        .to_return(
          status: 200,
          body: { status: "success", data: { activeTargets: targets } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      stub_request(:get, %r{#{Regexp.escape(base)}/api/v1/labels.*})
        .to_return(
          status: 200,
          body: { status: "success", data: [ "__name__", "instance", "job" ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end

  # Стаб всех эндпоинтов сразу — для дашборда, который дергает всё подряд
  def stub_prometheus_all
    stub_prometheus_query
    stub_prometheus_range
    stub_prometheus_meta
  end

  def stub_prometheus_down
    prometheus_base_urls.each do |base|
      stub_request(:get, %r{#{Regexp.escape(base)}/api/v1/.*}).to_timeout
    end
  end

  def default_up_result
    [
      { "metric" => { "instance" => "server1", "job" => "node" }, "value" => [ 1_700_000_000, "1" ] },
      { "metric" => { "instance" => "postgres:5432", "job" => "postgres" }, "value" => [ 1_700_000_000, "0" ] }
    ]
  end

  def default_range_result
    [
      {
        "metric" => { "instance" => "server1", "job" => "rails_dashboard" },
        "values" => [ [ 1_700_000_000, "42.5" ], [ 1_700_000_060, "43.1" ] ]
      }
    ]
  end

  def default_targets
    [
      {
        "labels" => { "instance" => "server1", "job" => "node" },
        "health" => "up",
        "lastScrape" => "2026-01-01T00:00:00Z",
        "lastError" => "",
        "scrapeUrl" => "http://server1/metrics"
      }
    ]
  end
end

# Хелперы для стаба ML-сервиса (MlService через HTTParty на ML_SERVICE_URL)
module MlServiceStubs
  def ml_base_url
    ENV["ML_SERVICE_URL"] || "http://localhost:5000"
  end

  def stub_ml_health(ok: true)
    stub_request(:get, "#{ml_base_url}/health")
      .to_return(status: ok ? 200 : 503, body: { status: ok ? "ok" : "error" }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_ml_detect_anomalies(response: { "status" => "ok", "anomalies" => [] })
    stub_request(:post, "#{ml_base_url}/detect_anomalies")
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_ml_predict_trend(response: { "status" => "ok", "trend" => "stable", "predictions" => [] })
    stub_request(:post, "#{ml_base_url}/predict_trend")
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end
end

RSpec.configure do |config|
  config.include PrometheusStubs
  config.include MlServiceStubs
end
