class MetricsService
  # Метод для получения данных метрики по имени (использует range query)
  # Возвращает данные первой серии для обратной совместимости
  def self.fetch_data(metric_name:, start_time:, end_time:, step: '1h')
    begin
      prometheus_service = PrometheusService.new
      results = prometheus_service.fetch_metrics_range(metric_name, start_time: start_time, end_time: end_time, step: step)
      
      return { values: [], timestamps: [] } if results.empty?
      
      # Преобразуем данные в нужный формат
      values = []
      timestamps = []
      
      result = results.first
      result[:values].each do |timestamp, value|
        timestamps << timestamp.to_i
        values << value.to_f
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
  
  # Метод для получения ВСЕХ серий метрики
  def self.fetch_all_series(metric_name:, start_time:, end_time:, step: '1h')
    begin
      prometheus_service = PrometheusService.new
      results = prometheus_service.fetch_metrics_range(metric_name, start_time: start_time, end_time: end_time, step: step)
      
      return [] if results.empty?
      
      # Возвращаем все серии с их labels
      results.map do |result|
        values = []
        timestamps = []
        
        result[:values].each do |timestamp, value|
          timestamps << timestamp.to_i
          values << value.to_f
        end
        
        # Формируем label для серии
        labels = result[:metric] || {}
        label = labels['instance'] || labels['job'] || 'unknown'
        
        {
          label: label,
          labels: labels,
          values: values,
          timestamps: timestamps
        }
      end
    rescue => e
      Rails.logger.error("Error fetching all series: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      return []
    end
  end
end