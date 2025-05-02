class MetricsService
  # Метод для получения данных метрики по имени
  def self.fetch_data(metric_name:, start_time:, end_time:, step: '1h')
    begin
      prometheus_service = PrometheusService.new
      results = prometheus_service.fetch_metrics(metric_name, step)
      
      return { values: [], timestamps: [] } if results.empty?
      
      # Преобразуем данные в нужный формат
      values = []
      timestamps = []
      
      result = results.first
      result[:values].each do |timestamp, value|
        # Проверяем, что timestamp попадает в указанный интервал
        if timestamp.to_i >= start_time && timestamp.to_i <= end_time
          timestamps << timestamp.to_i
          values << value.to_f
        end
      end
      
      return {
        values: values,
        timestamps: timestamps
      }
    rescue => e
      Rails.logger.error("Error fetching metrics data: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      return { values: [], timestamps: [] }
    end
  end
end