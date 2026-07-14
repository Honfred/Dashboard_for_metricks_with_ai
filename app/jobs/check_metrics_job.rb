class CheckMetricsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "Starting CheckMetricsJob at #{Time.current}"

    alerts_service = AlertsService.new
    begin
      alerts_service.check_all_metrics
      Rails.logger.info "CheckMetricsJob completed successfully at #{Time.current}"
    rescue => e
      Rails.logger.error "Error in CheckMetricsJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  # Метод для повторного планирования задачи
  after_perform do |job|
    # Планируем следующий запуск через 5 минут
    CheckMetricsJob.set(wait: 5.minutes).perform_later
  end
end
