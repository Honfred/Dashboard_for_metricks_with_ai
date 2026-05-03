class AlertsService
  attr_reader :prometheus_service

  def initialize
    @prometheus_service = PrometheusService.new
  end

  # Проверяет метрики и создает оповещения при необходимости
  def check_all_metrics
    check_response_time
    check_error_rate
    check_service_health
  end

  # Проверяет все сервисы на работоспособность
  def check_service_health
    targets = @prometheus_service.available_metrics
    services = targets.map { |t| t[:instance] }

    triggered = Alert.triggered_for(services, 'service_availability').index_by(&:service)

    targets.each do |target|
      service = target[:instance]

      if !target[:active]
        Alert.trigger_for(service, 'service_availability', 0, 1, 'critical', "Сервис #{service} недоступен")
      else
        triggered[service]&.resolve!
      end
    end
  end

  # Проверяет время отклика всех сервисов
  def check_response_time
    result = @prometheus_service.query_prometheus("http_request_duration_seconds")
    return unless result["status"] == "success"

    series_list = result["data"]["result"]
    services = series_list.map { |s| s["metric"]["instance"] || s["metric"]["job"] || "unknown" }
    triggered = Alert.triggered_for(services, 'response_time').index_by(&:service)

    series_list.each do |series|
      service   = series["metric"]["instance"] || series["metric"]["job"] || "unknown"
      value     = series["value"][1].to_f
      threshold = get_threshold_for(service, 'response_time', 0.5)

      if value > threshold
        severity = if value > threshold * 2 then 'critical'
                   elsif value > threshold * 1.5 then 'warning'
                   else 'info'
                   end
        Alert.trigger_for(service, 'response_time', value, threshold, severity,
          "Время отклика #{service} превышает порог #{threshold}s и составляет #{value.round(2)}s")
      else
        triggered[service]&.resolve!
      end
    end
  end

  # Проверяет уровень ошибок всех сервисов
  def check_error_rate
    query = 'rate(http_requests_total{status=~"5.."}[1m]) / rate(http_requests_total[1m])'
    result = @prometheus_service.query_prometheus(query)
    return unless result["status"] == "success"

    series_list = result["data"]["result"]
    services = series_list.map { |s| s["metric"]["instance"] || s["metric"]["job"] || "unknown" }
    triggered = Alert.triggered_for(services, 'error_rate').index_by(&:service)

    series_list.each do |series|
      service   = series["metric"]["instance"] || series["metric"]["job"] || "unknown"
      value     = series["value"][1].to_f
      threshold = get_threshold_for(service, 'error_rate', 0.05)

      if value > threshold
        severity = if value > threshold * 3 then 'critical'
                   elsif value > threshold * 2 then 'warning'
                   else 'info'
                   end
        Alert.trigger_for(service, 'error_rate', value, threshold, severity,
          "Уровень ошибок #{service} превышает порог #{(threshold * 100).round(1)}% и составляет #{(value * 100).round(1)}%")
      else
        triggered[service]&.resolve!
      end
    end
  end

  private

  # Получение порогового значения для сервиса и метрики
  # В будущем можно расширить для хранения пороговых значений в базе данных
  def get_threshold_for(service, metric, default_value)
    # Здесь можно добавить логику получения пороговых значений из базы данных или конфигурации
    # Пока что возвращаем значение по умолчанию
    default_value
  end
end 