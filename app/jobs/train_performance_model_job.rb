class TrainPerformanceModelJob < ApplicationJob
  include MetricDataFetchable
  
  queue_as :ml

  def perform(metric_name)
    metric = Metric.find_by(name: metric_name)
    return unless metric
    
    # Для CPU метрики используем память и HTTP запросы как признаки
    if metric_name == "cpu_usage"
      # Период для сбора данных
      start_time = 1.month.ago
      end_time = Time.now
      
      # Получаем данные целевой метрики
      target_data = fetch_metric_data(metric, start_time, end_time)
      return if target_data[:values].empty?
      
      # Получаем данные метрик, используемых как признаки
      memory_metric = Metric.find_by(name: "memory_usage_bytes")
      requests_metric = Metric.find_by(name: "http_requests_total")
      
      return unless memory_metric && requests_metric
      
      memory_data = fetch_metric_data(memory_metric, start_time, end_time)
      requests_data = fetch_metric_data(requests_metric, start_time, end_time)
      
      # Формируем признаки и целевые значения
      # Примечание: в реальном случае нужно будет синхронизировать данные по времени
      features = []
      target = []
      
      # Находим общие временные метки для всех данных
      timestamps = target_data[:timestamps] & memory_data[:timestamps] & requests_data[:timestamps]
      
      timestamps.each do |timestamp|
        target_idx = target_data[:timestamps].index(timestamp)
        memory_idx = memory_data[:timestamps].index(timestamp)
        requests_idx = requests_data[:timestamps].index(timestamp)
        
        next unless target_idx && memory_idx && requests_idx
        
        # Добавляем точку данных
        features << [
          memory_data[:values][memory_idx],
          requests_data[:values][requests_idx]
        ]
        
        target << target_data[:values][target_idx]
      end
      
      if features.empty? || target.empty?
        Rails.logger.error("No synchronized data points found for performance model")
        return
      end
      
      # Вызываем ML сервис
      result = MlService.train_performance_model(metric_name, features, target)
      
      if result["status"] == "success"
        Rails.logger.info("Performance model for #{metric_name} trained successfully")
        update_model_status(metric, "performance", true, result["model_id"], "cpu_model")
      else
        Rails.logger.error("Failed to train performance model: #{result["message"]}")
        update_model_status(metric, "performance", false)
      end
    elsif metric_name == "memory_usage_bytes"
      # Логика для обучения модели memory_usage_bytes
      process_memory_model(metric)
    elsif metric_name == "http_request_duration_seconds"
      # Логика для обучения модели времени ответа HTTP запросов
      process_request_duration_model(metric)
    else
      Rails.logger.info("No feature definition for #{metric_name} in performance model, skipping")
    end
  end
  
  private
  
  # Обработка модели использования памяти
  def process_memory_model(metric)
    start_time = 1.month.ago
    end_time = Time.now
    
    target_data = fetch_metric_data(metric, start_time, end_time)
    return if target_data[:values].empty?
    
    # Получаем данные о количестве активных пользователей как признак
    users_metric = Metric.find_by(name: "active_users")
    requests_metric = Metric.find_by(name: "http_requests_total")
    
    return unless users_metric && requests_metric
    
    users_data = fetch_metric_data(users_metric, start_time, end_time)
    requests_data = fetch_metric_data(requests_metric, start_time, end_time)
    
    features = []
    target = []
    
    timestamps = target_data[:timestamps] & users_data[:timestamps] & requests_data[:timestamps]
    
    timestamps.each do |timestamp|
      target_idx = target_data[:timestamps].index(timestamp)
      users_idx = users_data[:timestamps].index(timestamp)
      requests_idx = requests_data[:timestamps].index(timestamp)
      
      next unless target_idx && users_idx && requests_idx
      
      features << [
        users_data[:values][users_idx],
        requests_data[:values][requests_idx]
      ]
      
      target << target_data[:values][target_idx]
    end
    
    if features.empty? || target.empty?
      Rails.logger.error("No synchronized data points found for memory performance model")
      return
    end
    
    result = MlService.train_performance_model("memory_usage_bytes", features, target)
    
    if result["status"] == "success"
      Rails.logger.info("Performance model for memory_usage_bytes trained successfully")
      update_model_status(metric, "performance", true, result["model_id"], "memory_model")
    else
      Rails.logger.error("Failed to train memory performance model: #{result["message"]}")
      update_model_status(metric, "performance", false)
    end
  end
  
  # Обработка модели времени ответа HTTP запросов
  def process_request_duration_model(metric)
    start_time = 15.days.ago
    end_time = Time.now
    
    target_data = fetch_metric_data(metric, start_time, end_time)
    return if target_data[:values].empty?
    
    # Признаки для модели времени ответа
    cpu_metric = Metric.find_by(name: "cpu_usage")
    memory_metric = Metric.find_by(name: "memory_usage_bytes")
    requests_metric = Metric.find_by(name: "http_requests_total")
    
    return unless cpu_metric && memory_metric && requests_metric
    
    cpu_data = fetch_metric_data(cpu_metric, start_time, end_time)
    memory_data = fetch_metric_data(memory_metric, start_time, end_time)
    requests_data = fetch_metric_data(requests_metric, start_time, end_time)
    
    features = []
    target = []
    
    timestamps = target_data[:timestamps] & cpu_data[:timestamps] & memory_data[:timestamps] & requests_data[:timestamps]
    
    timestamps.each do |timestamp|
      target_idx = target_data[:timestamps].index(timestamp)
      cpu_idx = cpu_data[:timestamps].index(timestamp)
      memory_idx = memory_data[:timestamps].index(timestamp)
      requests_idx = requests_data[:timestamps].index(timestamp)
      
      next unless target_idx && cpu_idx && memory_idx && requests_idx
      
      features << [
        cpu_data[:values][cpu_idx],
        memory_data[:values][memory_idx],
        requests_data[:values][requests_idx]
      ]
      
      target << target_data[:values][target_idx]
    end
    
    if features.empty? || target.empty?
      Rails.logger.error("No synchronized data points found for request duration performance model")
      return
    end
    
    result = MlService.train_performance_model("http_request_duration_seconds", features, target)
    
    if result["status"] == "success"
      Rails.logger.info("Performance model for http_request_duration_seconds trained successfully")
      update_model_status(metric, "performance", true, result["model_id"], "request_duration_model")
    else
      Rails.logger.error("Failed to train request duration performance model: #{result["message"]}")
      update_model_status(metric, "performance", false)
    end
  end
  
  # Обновление статуса модели в базе данных
  def update_model_status(metric, model_type, success, model_id = nil, subtype = nil)
    model_info = metric.model_info || {}
    model_info[model_type] = {
      last_trained_at: Time.current,
      status: success ? "success" : "failed",
      model_id: model_id,
      subtype: subtype
    }
    
    metric.update(model_info: model_info)
  rescue => e
    Rails.logger.error("Failed to update model status: #{e.message}")
  end
end