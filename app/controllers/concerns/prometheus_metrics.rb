module PrometheusMetrics
  extend ActiveSupport::Concern

  @@registry = Prometheus::Client.registry
  
  # Инициализация счетчиков и метрик при первом использовании
  @@request_count = begin
    @@registry.counter(
      :rails_http_requests_total,
      docstring: 'Общее количество HTTP запросов.',
      labels: [:method, :path, :status]
    )
  rescue Prometheus::Client::Registry::AlreadyRegisteredError
    @@registry.get(:rails_http_requests_total)
  end

  @@request_duration = begin
    @@registry.histogram(
      :rails_http_request_duration_seconds,
      docstring: 'Время обработки HTTP запросов.',
      labels: [:method, :path, :status],
      buckets: [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
    )
  rescue Prometheus::Client::Registry::AlreadyRegisteredError
    @@registry.get(:rails_http_request_duration_seconds)
  end

  @@db_duration = begin
    @@registry.histogram(
      :rails_db_query_duration_seconds,
      docstring: 'Время выполнения SQL запросов.',
      labels: [:query_name],
      buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1]
    )
  rescue Prometheus::Client::Registry::AlreadyRegisteredError
    @@registry.get(:rails_db_query_duration_seconds)
  end

  @@view_duration = begin
    @@registry.histogram(
      :rails_view_render_duration_seconds,
      docstring: 'Время рендеринга представлений.',
      labels: [:view_name],
      buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5]
    )
  rescue Prometheus::Client::Registry::AlreadyRegisteredError
    @@registry.get(:rails_view_render_duration_seconds)
  end

  included do
    # Метод included вызывается при подключении модуля к классу
  end

  # Получение текущего реестра метрик
  def self.registry
    @@registry
  end

  # Обновление счетчика запросов
  def self.record_request(method, path, status, duration)
    @@request_count.increment(labels: { method: method, path: path, status: status })
    @@request_duration.observe(duration, labels: { method: method, path: path, status: status })
  end

  # Запись времени выполнения SQL-запроса
  def self.record_db_query(name, duration)
    @@db_duration.observe(duration, labels: { query_name: name })
  end

  # Запись времени рендеринга представления
  def self.record_view_render(name, duration)
    @@view_duration.observe(duration, labels: { view_name: name })
  end
end 