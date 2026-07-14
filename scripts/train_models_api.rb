#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'optparse'
require 'time'

# Параметры командной строки
options = {
  url: ENV['ML_SERVICE_URL'] || 'http://localhost:5000',
  metric: nil,
  model_type: nil
}

parser = OptionParser.new do |opts|
  opts.banner = "Использование: #{$0} [опции]"

  opts.on("-u", "--url URL", "URL API сервера ML (по умолчанию: http://localhost:5000)") do |url|
    options[:url] = url
  end

  opts.on("-m", "--metric NAME", "Имя метрики для обучения модели") do |metric|
    options[:metric] = metric
  end

  opts.on("-t", "--type TYPE", "Тип модели (anomaly, trend, performance)") do |type|
    options[:model_type] = type
  end

  opts.on_tail("-h", "--help", "Показать эту справку") do
    puts opts
    exit
  end
end

parser.parse!

# Проверка обязательных параметров
if options[:metric].nil? || options[:model_type].nil?
  puts "Обязательные параметры не указаны."
  puts parser
  exit 1
end

# Определение временных интервалов
SECONDS_IN_MONTH = 30 * 24 * 60 * 60
SECONDS_IN_DAY = 24 * 60 * 60
SECONDS_IN_HOUR = 60 * 60

# Класс для работы с ML API
class MlApiClient
  def initialize(base_url)
    @base_url = base_url
  end

  def train_anomaly_model(metric_name)
    puts "Обучение модели обнаружения аномалий для метрики #{metric_name}..."

    # Генерация тестовых данных (в реальном сценарии данные брались бы из базы данных или другого источника)
    now = Time.now.to_i
    one_month_ago = now - SECONDS_IN_MONTH
    timestamps = (one_month_ago..now).step(3600).to_a
    values = timestamps.map { |t| Math.sin(t / 10000.0) + rand * 0.5 }

    response = post_json('/train_anomaly_model', {
      metric_name: metric_name,
      values: values,
      timestamps: timestamps
    })

    puts "Результат: #{response['status'] == 'success' ? 'Успешно' : 'Ошибка'}"
    puts response['message'] if response['message']
    response
  end

  def train_trend_model(metric_name)
    puts "Обучение модели прогнозирования тренда для метрики #{metric_name}..."

    # Генерация тестовых данных
    now = Time.now.to_i
    three_months_ago = now - 3 * SECONDS_IN_MONTH
    timestamps = (three_months_ago..now).step(3600).to_a
    values = timestamps.map { |t|
      # Базовый тренд + сезонные колебания + немного шума
      base = t / 1000000.0  # базовый тренд вверх
      seasonal = Math.sin(t / 86400.0 * 2 * Math::PI) * 2.0  # дневная сезонность
      weekly = Math.sin(t / 604800.0 * 2 * Math::PI) * 5.0   # недельная сезонность
      noise = rand - 0.5  # случайный шум
      base + seasonal + weekly + noise
    }

    response = post_json('/train_trend_model', {
      metric_name: metric_name,
      values: values,
      timestamps: timestamps
    })

    puts "Результат: #{response['status'] == 'success' ? 'Успешно' : 'Ошибка'}"
    puts response['message'] if response['message']
    response
  end

  def train_performance_model(metric_name)
    puts "Обучение модели производительности для метрики #{metric_name}..."

    # Генерация тестовых данных
    # Для модели производительности нужны признаки и целевые значения
    # Признаки: например, если это CPU модель - то нужны memory и requests
    features = []
    target = []

    # Генерируем 1000 тестовых точек данных
    1000.times do |i|
      if metric_name == "cpu_usage"
        # Признаки: память и количество запросов
        memory = rand * 8000 + 2000  # память от 2GB до 10GB
        requests = rand * 500 + 50   # от 50 до 550 запросов

        # Целевые значения (CPU) с зависимостью от признаков
        cpu = memory * 0.01 + requests * 0.05 + rand * 10

        features << [ memory, requests ]
        target << cpu
      elsif metric_name == "memory_usage_bytes"
        # Признаки: активные пользователи и запросы
        users = rand * 100 + 10      # от 10 до 110 пользователей
        requests = rand * 500 + 50   # от 50 до 550 запросов

        # Целевые значения (память)
        memory = users * 50000 + requests * 10000 + rand * 1000000

        features << [ users, requests ]
        target << memory
      elsif metric_name == "http_request_duration_seconds"
        # Признаки: CPU, память и количество запросов
        cpu = rand * 80 + 10         # CPU от 10% до 90%
        memory = rand * 8000 + 2000  # память от 2GB до 10GB
        requests = rand * 500 + 50   # от 50 до 550 запросов

        # Целевые значения (время ответа)
        duration = cpu * 0.005 + memory * 0.0001 + requests * 0.002 + rand * 0.1

        features << [ cpu, memory, requests ]
        target << duration
      else
        puts "Неизвестная метрика для модели производительности: #{metric_name}"
        return { 'status' => 'error', 'message' => "Неизвестная метрика" }
      end
    end

    response = post_json('/train_performance_model', {
      metric_name: metric_name,
      features: features,
      target: target
    })

    puts "Результат: #{response['status'] == 'success' ? 'Успешно' : 'Ошибка'}"
    puts "Важность признаков: #{response['feature_importance']}" if response['feature_importance']
    puts response['message'] if response['message']
    response
  end

  private

  def post_json(endpoint, data)
    uri = URI("#{@base_url}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = data.to_json

    begin
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        { 'status' => 'error', 'message' => "HTTP Error: #{response.code} #{response.message}" }
      end
    rescue => e
      { 'status' => 'error', 'message' => "Error: #{e.message}" }
    end
  end
end

# Главная функция для обучения моделей
def train_model(options)
  client = MlApiClient.new(options[:url])

  case options[:model_type]
  when 'anomaly'
    client.train_anomaly_model(options[:metric])
  when 'trend'
    client.train_trend_model(options[:metric])
  when 'performance'
    client.train_performance_model(options[:metric])
  else
    puts "Неизвестный тип модели: #{options[:model_type]}"
  end
end

# Запуск скрипта
train_model(options)
puts "Завершено."
