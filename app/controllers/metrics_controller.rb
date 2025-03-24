class MetricsController < ApplicationController
  before_action :set_metric, only: [ :show, :edit, :update, :destroy ]

  def index
    @metrics = Metric.all
    @available_targets = PrometheusService.new.available_metrics
  end

  def show
    @metric_data = Metric.fetch_from_prometheus(@metric.name, params[:time_range] || "1h")
    @ai_analyses = @metric.ai_analyses.order(created_at: :desc).limit(5)

    respond_to do |format|
      format.html
      format.json { render json: { metric: @metric, data: @metric_data } }
    end
  end

  def new
    @metric = Metric.new
  end

  def create
    @metric = Metric.new(metric_params)

    # Добавляем пример данных для тестирования
    if @metric.save
      # Временное создание демо-данных в Prometheus (в реальной системе этого не нужно)
      create_demo_metrics(@metric.name, @metric.metric_type)
      
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

  private

  def set_metric
    @metric = Metric.find(params[:id])
  end

  def metric_params
    params.require(:metric).permit(:name, :description, :metric_type)
  end

  # Метод для создания демонстрационных метрик
  def create_demo_metrics(metric_name, metric_type)
    # Эта функция в реальности бы добавляла данные в Prometheus
    # Но так как мы просто демонстрируем интерфейс, мы "притворяемся", что метрики добавлены
    Rails.logger.info "Демонстрационные метрики для #{metric_name} (#{metric_type}) добавлены в Prometheus"
    # В реальной системе здесь был бы код для регистрации в Prometheus
  end
end
