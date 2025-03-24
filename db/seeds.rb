# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Добавление демонстрационных метрик

puts "Создание демонстрационных метрик..."

# Удаляем все существующие метрики для чистого старта
Metric.destroy_all

# Создаем метрики для мониторинга API
api_response_time = Metric.create!(
  name: "http_request_duration_seconds",
  description: "Время отклика API в секундах",
  metric_type: "histogram"
)
puts "Создана метрика: #{api_response_time.name}"

# Метрика для отслеживания количества запросов
request_count = Metric.create!(
  name: "http_requests_total",
  description: "Общее количество HTTP запросов",
  metric_type: "counter"
)
puts "Создана метрика: #{request_count.name}"

# Метрика для отслеживания ошибок
error_rate = Metric.create!(
  name: "http_requests_errors_total",
  description: "Количество ошибок HTTP запросов",
  metric_type: "counter"
)
puts "Создана метрика: #{error_rate.name}"

# Метрика для мониторинга CPU
cpu_usage = Metric.create!(
  name: "process_cpu_seconds_total",
  description: "Использование CPU процессами",
  metric_type: "gauge"
)
puts "Создана метрика: #{cpu_usage.name}"

# Метрика для мониторинга памяти
memory_usage = Metric.create!(
  name: "process_resident_memory_bytes",
  description: "Использование оперативной памяти процессами",
  metric_type: "gauge"
)
puts "Создана метрика: #{memory_usage.name}"

# Метрика для мониторинга времени выполнения JOB задач
job_duration = Metric.create!(
  name: "sidekiq_job_duration_seconds",
  description: "Время выполнения Sidekiq задач",
  metric_type: "histogram"
)
puts "Создана метрика: #{job_duration.name}"

# Метрика для мониторинга статуса сервисов
service_status = Metric.create!(
  name: "up",
  description: "Статус работы сервисов (1=активен, 0=неактивен)",
  metric_type: "gauge"
)
puts "Создана метрика: #{service_status.name}"

puts "Всего создано метрик: #{Metric.count}"
