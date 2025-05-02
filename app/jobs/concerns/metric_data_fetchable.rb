module MetricDataFetchable
  # Метод для получения данных метрики из внешней системы
  def fetch_metric_data(metric, start_time, end_time, step: '1h')
    begin
      data = MetricsService.fetch_data(
        metric_name: metric.name,
        start_time: start_time.to_i,
        end_time: end_time.to_i,
        step: step
      )
      
      return {
        values: data[:values] || [],
        timestamps: data[:timestamps] || []
      }
    rescue => e
      Rails.logger.error("Failed to fetch metrics for #{metric.name}: #{e.message}")
      return { values: [], timestamps: [] }
    end
  end
end