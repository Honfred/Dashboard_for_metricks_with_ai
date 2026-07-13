require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require "prometheus/middleware/collector"
require "prometheus/client/formats/text"

module DashboardForMetricksWithAi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    
    # Сбор реальных метрик HTTP-запросов (http_server_requests_total,
    # http_server_request_duration_seconds) — их отдаёт эндпоинт /metrics
    config.middleware.use Prometheus::Middleware::Collector

    # Настройка соединения с Prometheus
    config.prometheus_url = ENV["PROMETHEUS_URL"] || "http://localhost:9090"

    # Настройка соединения с микросервисом ИИ-анализа
    config.ai_service_url = ENV["AI_SERVICE_URL"] || "http://localhost:5000"

    # Настройка локализации i18n
    config.i18n.available_locales = [:ru, :en]
    config.i18n.default_locale = :ru
    config.i18n.fallbacks = true
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
  end
end
