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
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @metric.update(metric_params)
      redirect_to @metric, notice: "Метрика успешно обновлена."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @metric.destroy
    redirect_to metrics_url, notice: "Метрика успешно удалена."
  end

  # Метод для возврата метрик в формате, понятном для Prometheus.
  # Отдаёт реальные метрики приложения из реестра prometheus-client
  # (запросы считает Prometheus::Middleware::Collector)
  def custom_metrics
    begin
      response_body = Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)
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
