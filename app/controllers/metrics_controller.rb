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

  private

  def set_metric
    @metric = Metric.find(params[:id])
  end

  def metric_params
    params.require(:metric).permit(:name, :description, :metric_type)
  end
end
