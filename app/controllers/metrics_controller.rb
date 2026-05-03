class MetricsController < ApplicationController
  before_action :set_metric, only: [ :show, :edit, :update, :destroy ]
  skip_before_action :verify_authenticity_token, only: :custom_metrics

  def index
    @metrics = Metric.all
    @available_targets = PrometheusService.new.available_metrics
  end

  def show
    Rails.logger.info("MetricsController#show - Запрос метрики #{@metric.name} с диапазоном #{params[:time_range] || '1h'}")
    
    # Получаем данные метрики из единого метода
    @metric_data = get_metric_data(@metric.name, params[:time_range] || "1h")
    
    @ai_analyses = @metric.ai_analyses.order(created_at: :desc).limit(5)

    respond_to do |format|
      format.html
      format.json { 
        response_data = { metric: @metric, data: @metric_data }
        Rails.logger.info("MetricsController#show - Отдаю JSON: #{response_data.inspect.truncate(100)}") 
        render json: response_data
      }
    end
  end

  def new
    @metric = Metric.new
  end

  def create
    @metric = Metric.new(metric_params)

    if @metric.save
      redirect_to @metric, notice: "Метрика успешно создана."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @metric.update(metric_params)
      redirect_to @metric, notice: "Метрика успешно обновлена."
    else
      render :edit
    end
  end

  def destroy
    @metric.destroy
    redirect_to metrics_url, notice: "Метрика успешно удалена."
  end

  # Метод для возврата метрик в формате, понятном для Prometheus
  def custom_metrics
    begin
      # Получаем данные статистики приложения
      metrics_data = collect_application_metrics
      
      # Формируем ответ в формате Prometheus
      response_body = generate_prometheus_format(metrics_data)
      
      # Отправляем ответ с правильным content-type
      render plain: response_body, content_type: 'text/plain; version=0.0.4'
    rescue => e
      Rails.logger.error("Error generating custom metrics: #{e.message}")
      render plain: "# Error generating metrics: #{e.message}", content_type: 'text/plain; version=0.0.4', status: :internal_server_error
    end
  end

  def analyze
    @metric = Metric.find(params[:id])

    result = Rails.cache.fetch("metric_analyze:#{@metric.id}", expires_in: 10.minutes) do
      end_time = Time.now
      start_time = end_time - 24.hours

      data = MetricsService.fetch_data(
        metric_name: @metric.name,
        start_time: start_time.to_i,
        end_time: end_time.to_i,
        step: '5m'
      )

      {
        metric: @metric.as_json,
        anomalies: detect_anomalies(@metric.name, data),
        trend: predict_trend(@metric.name)
      }
    end

    render json: result
  end

  def check_ml_service
    status = MlService.check_connection ? 'ok' : 'error'
    render json: { status: status }
  end

  private

  def set_metric
    @metric = Metric.find(params[:id])
  end

  def metric_params
    params.require(:metric).permit(:name, :description, :metric_type)
  end

  # Метод для получения данных метрики из Prometheus
  def get_metric_data(metric_name, time_range)
    cache_key = "metric_data:#{metric_name}:#{time_range}"

    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      data = Metric.fetch_from_prometheus(metric_name, time_range)

      if data.blank? || !data.is_a?(Array) || data.empty? || (data.first && data.first[:values].blank?)
        Rails.logger.warn("MetricsController#get_metric_data - Данные метрики отсутствуют для #{metric_name}")
        []
      else
        Rails.logger.info("MetricsController#get_metric_data - Получены данные от Prometheus")
        data
      end
    end
  end



  # Собираем метрики приложения для Prometheus
  def collect_application_metrics
    {
      # Основные метрики Rails-приложения
      'rails_requests_total' => {
        type: 'counter',
        help: 'Total number of requests processed by the Rails application',
        value: rand(1000..5000)
      },
      'rails_request_duration_seconds' => {
        type: 'histogram',
        help: 'Request duration histogram in seconds',
        value: rand(0.1..2.0).round(3)
      },
      'rails_memory_usage_bytes' => {
        type: 'gauge',
        help: 'Memory usage of the Rails application in bytes',
        value: rand(100_000_000..500_000_000)
      },
      'rails_active_record_connections' => {
        type: 'gauge',
        help: 'Number of active database connections',
        value: rand(1..10)
      }
    }
  end

  # Генерируем текстовый формат для Prometheus
  def generate_prometheus_format(metrics_data)
    output = []
    
    metrics_data.each do |metric_name, metric_info|
      # Добавляем HELP комментарий (описание метрики)
      output << "# HELP #{metric_name} #{metric_info[:help]}"
      # Добавляем TYPE комментарий (тип метрики)
      output << "# TYPE #{metric_name} #{metric_info[:type]}"
      # Добавляем значение метрики
      output << "#{metric_name} #{metric_info[:value]}"
      # Добавляем пустую строку для лучшей читаемости
      output << ""
    end
    
    output.join("\n")
  end

  def detect_anomalies(metric_name, data)
    return { error: "No data available" } if data[:values].empty?
    
    MlService.detect_anomalies(
      metric_name,
      data[:values],
      data[:timestamps]
    )
  rescue => e
    Rails.logger.error("Error detecting anomalies: #{e.message}")
    { error: "Failed to detect anomalies: #{e.message}" }
  end
  
  def predict_trend(metric_name)
    MlService.predict_trend(metric_name, 24) # Прогноз на 24 часа вперед
  rescue => e
    Rails.logger.error("Error predicting trend: #{e.message}")
    { error: "Failed to predict trend: #{e.message}" }
  end
end
