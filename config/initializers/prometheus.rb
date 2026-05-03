# frozen_string_literal: true

require 'prometheus/client'

# Initialize Prometheus client
prometheus = Prometheus::Client.registry

# Define custom metrics
begin
  prometheus.counter(
    :http_requests_total,
    docstring: 'Total HTTP requests',
    labels: [:method, :path, :status]
  )
rescue Prometheus::Client::Registry::AlreadyRegisteredError
  # Metric already registered, skip
end

begin
  prometheus.histogram(
    :http_request_duration_seconds,
    docstring: 'HTTP request duration in seconds',
    labels: [:method, :path],
    buckets: [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
  )
rescue Prometheus::Client::Registry::AlreadyRegisteredError
  # Metric already registered, skip
end
