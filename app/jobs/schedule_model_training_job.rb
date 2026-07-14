class ScheduleModelTrainingJob < ApplicationJob
  queue_as :default

  def perform
    Metric.pluck(:name).each do |metric_name|
      # Запускаем обучение всех моделей
      TrainAnomalyModelJob.perform_later(metric_name)
      TrainTrendModelJob.perform_later(metric_name)

      # Для моделей производительности обучаем только определенные метрики
      if [ "cpu_usage", "memory_usage_bytes", "http_request_duration_seconds" ].include?(metric_name)
        TrainPerformanceModelJob.perform_later(metric_name)
      end
    end

    # Планируем следующий запуск через неделю
    ScheduleModelTrainingJob.set(wait: 1.week).perform_later
  end
end
