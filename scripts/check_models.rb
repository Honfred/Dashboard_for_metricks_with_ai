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
  action: nil
}

parser = OptionParser.new do |opts|
  opts.banner = "Использование: #{$0} [опции]"

  opts.on("-u", "--url URL", "URL API сервера ML (по умолчанию: http://localhost:5000)") do |url|
    options[:url] = url
  end

  opts.on("-m", "--metric NAME", "Имя метрики для проверки") do |metric|
    options[:metric] = metric
  end

  opts.on("-a", "--action ACTION", "Действие (anomalies, trend, performance)") do |action|
    options[:action] = action
  end

  opts.on_tail("-h", "--help", "Показать эту справку") do
    puts opts
    exit
  end
end

parser.parse!

# Проверка обязательных параметров
if options[:metric].nil? || options[:action].nil?
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

  def detect_anomalies(metric_name)
    puts "Обнаружение аномалий для метрики #{metric_name}..."

    # Генерация тестовых данных с некоторыми аномалиями
    now = Time.now.to_i
    twentyfour_hours_ago = now - 24 * SECONDS_IN_HOUR
    timestamps = (twentyfour_hours_ago..now).step(300).to_a # 5-минутные интервалы
    values = timestamps.map { |t|
      base = Math.sin(t / 10000.0) + Math.cos(t / 5000.0)

      # Добавляем аномалии в некоторые точки
      if rand < 0.05  # 5% точек будут аномальными
        base + (rand > 0.5 ? 5 : -5) * rand  # сильное отклонение
      else
        base + rand * 0.5  # нормальный шум
      end
    }

    response = post_json('/detect_anomalies', {
      metric_name: metric_name,
      values: values,
      timestamps: timestamps
    })

    if response['status'] == 'success'
      puts "Обнаружено #{response['anomalies'].size} аномалий из #{values.size} точек данных"
      if response['anomalies'].any?
        puts "Примеры аномалий:"
        response['anomalies'].take(3).each do |anomaly|
          time = Time.at(anomaly['timestamp'])
          puts "  - #{time}: значение #{anomaly['value']}, оценка: #{anomaly['score']}"
        end
      else
        puts "Аномалий не обнаружено"
      end
    else
      puts "Ошибка обнаружения аномалий: #{response['message']}"
    end

    response
  end

  def predict_trend(metric_name)
    puts "Прогнозирование тренда для метрики #{metric_name}..."

    # По умолчанию прогноз на 24 часа вперед
    response = post_json('/predict_trend', {
      metric_name: metric_name,
      periods: 24
    })

    if response['status'] == 'success'
      puts "Получен прогноз на #{response['prediction'].size} периодов"
      puts "Примеры прогноза:"
      response['prediction'].take(3).each do |pred|
        time = Time.at(pred['timestamp'])
        puts "  - #{time}: значение #{pred['value'].round(2)}, диапазон: [#{pred['lower_bound'].round(2)}, #{pred['upper_bound'].round(2)}]"
      end
    else
      puts "Ошибка прогнозирования тренда: #{response['message']}"
    end

    response
  end

  def analyze_performance(metric_name)
    puts "Анализ производительности для метрики #{metric_name}..."

    # Генерация тестовых данных для анализа
    features = []

    # Подготовка параметров в зависимости от метрики
    if metric_name == "cpu_usage"
      # Пробуем разные комбинации параметров
      [ 1000, 2000, 4000, 8000 ].each do |memory|
        [ 50, 100, 200, 400 ].each do |requests|
          features << [ memory, requests ]
        end
      end
    elsif metric_name == "memory_usage_bytes"
      [ 10, 20, 50, 100 ].each do |users|
        [ 50, 100, 200, 400 ].each do |requests|
          features << [ users, requests ]
        end
      end
    elsif metric_name == "http_request_duration_seconds"
      [ 20, 40, 60, 80 ].each do |cpu|
        [ 2000, 4000, 6000, 8000 ].each do |memory|
          [ 50, 200, 400 ].each do |requests|
            features << [ cpu, memory, requests ]
          end
        end
      end
    else
      puts "Неизвестная метрика для анализа производительности: #{metric_name}"
      return { 'status' => 'error', 'message' => "Неизвестная метрика" }
    end

    response = post_json('/analyze_performance', {
      metric_name: metric_name,
      features: features
    })

    if response['status'] == 'success'
      puts "Получены предсказания для #{response['predictions'].size} комбинаций параметров"
      puts "Важность признаков:"
      response['feature_importance'].each do |index, importance|
        puts "  - Признак #{index}: #{(importance * 100).round(2)}%"
      end

      # Анализ результатов
      predictions = response['predictions']
      case metric_name
      when "cpu_usage"
        puts "\nАнализ использования CPU:"
        analyze_predictions(features, predictions) do |feature, value|
          memory, requests = feature
          "Память: #{memory} MB, Запросы: #{requests}/с -> CPU: #{value.round(2)}%"
        end
      when "memory_usage_bytes"
        puts "\nАнализ использования памяти:"
        analyze_predictions(features, predictions) do |feature, value|
          users, requests = feature
          "Пользователей: #{users}, Запросы: #{requests}/с -> Память: #{(value / 1024 / 1024).round(2)} MB"
        end
      when "http_request_duration_seconds"
        puts "\nАнализ времени ответа на запросы:"
        analyze_predictions(features, predictions) do |feature, value|
          cpu, memory, requests = feature
          "CPU: #{cpu}%, Память: #{memory} MB, Запросы: #{requests}/с -> Время ответа: #{(value * 1000).round(2)} мс"
        end
      end
    else
      puts "Ошибка анализа производительности: #{response['message']}"
    end

    response
  end

  private

  # Метод для анализа и вывода наиболее интересных предсказаний
  def analyze_predictions(features, predictions, &formatter)
    # Находим минимальное и максимальное предсказания
    min_index = predictions.index(predictions.min)
    max_index = predictions.index(predictions.max)

    puts "  - Минимальное значение: #{formatter.call(features[min_index], predictions[min_index])}"
    puts "  - Максимальное значение: #{formatter.call(features[max_index], predictions[max_index])}"

    # Показываем несколько случайных предсказаний
    puts "  - Случайные значения:"
    3.times do
      idx = rand(predictions.size)
      puts "    * #{formatter.call(features[idx], predictions[idx])}"
    end
  end

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

# Главная функция для проверки моделей
def check_model(options)
  client = MlApiClient.new(options[:url])

  case options[:action]
  when 'anomalies'
    client.detect_anomalies(options[:metric])
  when 'trend'
    client.predict_trend(options[:metric])
  when 'performance'
    client.analyze_performance(options[:metric])
  else
    puts "Неизвестное действие: #{options[:action]}"
  end
end

# Запуск скрипта
check_model(options)
puts "Завершено."
