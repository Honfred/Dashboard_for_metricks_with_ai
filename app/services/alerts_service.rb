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
    
    targets.each do |target|
      service = target[:instance]
      is_up = target[:active]
      
      if !is_up
        # Создаем оповещение о недоступности сервиса
        Alert.trigger_for(
          service, 
          'service_availability', 
          0, 
          1, 
          'critical',
          "Сервис #{service} недоступен"
        )
      else
        # Если сервис снова доступен, решаем существующие оповещения
        alert = Alert.find_by(
          service: service, 
          metric: 'service_availability', 
          status: 'triggered'
        )
        
        alert&.resolve!
      end
    end
  end

  # Проверяет время отклика всех сервисов
  def check_response_time
    # Получаем данные о времени отклика
    end_time = Time.now
    start_time = end_time - 5.minutes
    step = '30s'
    
    result = @prometheus_service.query_prometheus("http_request_duration_seconds")
    
    return unless result["status"] == "success"
    
    result["data"]["result"].each do |series|
      service = series["metric"]["instance"] || series["metric"]["job"] || "unknown"
      value = series["value"][1].to_f
      
      threshold = get_threshold_for(service, 'response_time', 0.5) # 500ms по умолчанию
      
      if value > threshold
        # Определяем важность оповещения в зависимости от превышения порога
        severity = if value > threshold * 2
                    'critical'
                  elsif value > threshold * 1.5
                    'warning'
                  else
                    'info'
                  end
        
        Alert.trigger_for(
          service, 
          'response_time', 
          value, 
          threshold, 
          severity,
          "Время отклика #{service} превышает порог #{threshold}s и составляет #{value.round(2)}s"
        )
      else
        # Если метрика вернулась в норму, решаем существующие оповещения
        alert = Alert.find_by(
          service: service, 
          metric: 'response_time', 
          status: 'triggered'
        )
        
        alert&.resolve!
      end
    end
  end

  # Проверяет уровень ошибок всех сервисов
  def check_error_rate
    # Получаем данные об уровне ошибок
    query = 'rate(http_requests_total{status=~"5.."}[1m]) / rate(http_requests_total[1m])'
    result = @prometheus_service.query_prometheus(query)
    
    return unless result["status"] == "success"
    
    result["data"]["result"].each do |series|
      service = series["metric"]["instance"] || series["metric"]["job"] || "unknown"
      value = series["value"][1].to_f
      
      threshold = get_threshold_for(service, 'error_rate', 0.05) # 5% по умолчанию
      
      if value > threshold
        # Определяем важность оповещения в зависимости от превышения порога
        severity = if value > threshold * 3
                    'critical'
                  elsif value > threshold * 2
                    'warning'
                  else
                    'info'
                  end
        
        Alert.trigger_for(
          service, 
          'error_rate', 
          value, 
          threshold, 
          severity,
          "Уровень ошибок #{service} превышает порог #{(threshold * 100).round(1)}% и составляет #{(value * 100).round(1)}%"
        )
      else
        # Если метрика вернулась в норму, решаем существующие оповещения
        alert = Alert.find_by(
          service: service, 
          metric: 'error_rate', 
          status: 'triggered'
        )
        
        alert&.resolve!
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