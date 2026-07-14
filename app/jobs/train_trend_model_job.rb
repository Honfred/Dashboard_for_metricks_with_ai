class TrainTrendModelJob < ApplicationJob
  include MetricDataFetchable

  queue_as :ml

  def perform(metric_name)
    metric = Metric.find_by(name: metric_name)
    return unless metric

    # Получаем данные из внешнего источника за последние 3 месяца
    data = fetch_metric_data(metric, 3.months.ago, Time.now)

    return if data[:values].empty?

    # Вызываем ML сервис
    result = MlService.train_trend_model(
      metric_name,
      data[:values],
      data[:timestamps]
    )

    if result["status"] == "success"
      Rails.logger.info("Trend model for #{metric_name} trained successfully")
      update_model_status(metric, "trend", true, result["model_id"])
    else
      Rails.logger.error("Failed to train trend model for #{metric_name}: #{result["message"]}")
      update_model_status(metric, "trend", false)
    end
  end

  private

  # Обновление статуса модели в базе данных
  def update_model_status(metric, model_type, success, model_id = nil)
    model_info = metric.model_info || {}
    model_info[model_type] = {
      last_trained_at: Time.current,
      status: success ? "success" : "failed",
      model_id: model_id,
      forecast_horizon: model_type == "trend" ? "30d" : nil
    }

    metric.update(model_info: model_info)
  rescue => e
    Rails.logger.error("Failed to update model status: #{e.message}")
  end
end
