class MlService
  include HTTParty
  base_uri ENV["ML_SERVICE_URL"] || "http://localhost:5000"
  format :json

  # Тренировка модели для обнаружения аномалий
  def self.train_anomaly_model(metric_name, values, timestamps)
    post_request("/train_anomaly_model", {
      metric_name: metric_name,
      values: values,
      timestamps: timestamps
    })
  end

  # Обнаружение аномалий
  def self.detect_anomalies(metric_name, values, timestamps)
    Rails.logger.info("ML Service: Calling detect_anomalies for metric #{metric_name} with #{values.size} values")
    post_request("/detect_anomalies", {
      metric_name: metric_name,
      values: values,
      timestamps: timestamps
    })
  end

  # Тренировка модели для предсказания трендов
  def self.train_trend_model(metric_name, values, timestamps)
    post_request("/train_trend_model", {
      metric_name: metric_name,
      values: values,
      timestamps: timestamps
    })
  end

  # Предсказание тренда
  def self.predict_trend(metric_name, periods = 24, values: [], timestamps: [])
    Rails.logger.info("ML Service: Calling predict_trend for metric #{metric_name} with #{periods} periods")
    post_request("/predict_trend", {
      metric_name: metric_name,
      periods: periods,
      values: values,
      timestamps: timestamps
    })
  end

  # Тренировка модели для анализа производительности
  def self.train_performance_model(metric_name, features, target)
    post_request("/train_performance_model", {
      metric_name: metric_name,
      features: features,
      target: target
    })
  end

  # Анализ производительности
  def self.analyze_performance(metric_name, features)
    Rails.logger.info("ML Service: Calling analyze_performance for metric #{metric_name} with #{features.size} feature points")
    post_request("/analyze_performance", {
      metric_name: metric_name,
      features: features
    })
  end

  private

  def self.post_request(endpoint, body)
    url = "#{base_uri}#{endpoint}"
    Rails.logger.info("ML Service: Making POST request to #{url}")

    begin
      Timeout.timeout(60) do  # Добавляем таймаут в 60 секунд для запросов
        response = self.post(endpoint, {
          body: body.to_json,
          headers: { "Content-Type" => "application/json" }
        })

        if response.success?
          Rails.logger.info("ML Service: Successful response with code #{response.code}")
          return response.parsed_response
        else
          Rails.logger.error("ML Service error: #{response.code} - #{response.body}")
          return { "status" => "error", "message" => "Ошибка сервиса ML: #{response.message}" }
        end
      end
    rescue Timeout::Error => e
      Rails.logger.error("ML Service request timed out after 60 seconds")
      { "status" => "error", "message" => "Превышен таймаут запроса к ML-сервису (60 сек.)" }
    rescue => e
      Rails.logger.error("ML Service exception: #{e.class.name} - #{e.message}")
      { "status" => "error", "message" => "Ошибка соединения с ML сервисом: #{e.message}" }
    end
  end

  # Вспомогательный метод для проверки подключения к сервису
  def self.check_connection
    begin
      response = get("/health")
      response.success?
    rescue => e
      Rails.logger.error("ML Service connection check failed: #{e.message}")
      false
    end
  end
end
