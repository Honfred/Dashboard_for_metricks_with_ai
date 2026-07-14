module MetricDataFetchable
  # Метод для получения данных метрики из внешней системы (первая серия)
  def fetch_metric_data(metric, start_time, end_time, step: "1h")
    begin
      data = MetricsService.fetch_data(
        metric_name: metric.name,
        start_time: start_time.to_i,
        end_time: end_time.to_i,
        step: step
      )

      {
        values: data[:values] || [],
        timestamps: data[:timestamps] || []
      }
    rescue => e
      Rails.logger.error("Failed to fetch metrics for #{metric.name}: #{e.message}")
      { values: [], timestamps: [] }
    end
  end

  # Метод для получения ВСЕХ серий метрики
  def fetch_all_metric_series(metric, start_time, end_time, step: "1h")
    begin
      MetricsService.fetch_all_series(
        metric_name: metric.name,
        start_time: start_time.to_i,
        end_time: end_time.to_i,
        step: step
      )
    rescue => e
      Rails.logger.error("Failed to fetch all series for #{metric.name}: #{e.message}")
      []
    end
  end
end
