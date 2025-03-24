class AiAnalysesController < ApplicationController
  before_action :set_metric, except: [:index]
  before_action :set_ai_analysis, only: [:show]

  def index
    @ai_analyses = AiAnalysis.includes(:metric).order(created_at: :desc)
  end

  def show
    @analysis_data = AiAnalysis.fetch_latest_analysis(@metric.id, @ai_analysis.analysis_type)

    respond_to do |format|
      format.html
      format.json { render json: { analysis: @ai_analysis, data: @analysis_data } }
    end
  end

  def new
    @ai_analysis = @metric.ai_analyses.new
    @available_analysis_types = AiService.new.available_analysis_types
  end

  def create
    @ai_analysis = @metric.ai_analyses.new(ai_analysis_params)

    if @ai_analysis.save
      # Запускаем анализ асинхронно
      AnalysisJob.perform_later(@ai_analysis.id)
      redirect_to [@metric, @ai_analysis], notice: "Анализ успешно запущен."
    else
      render :new
    end
  end

  private

  def set_metric
    if params[:metric_id].present?
      @metric = Metric.find(params[:metric_id])
    else
      redirect_to ai_analyses_path, alert: "Необходимо выбрать метрику для анализа"
    end
  end

  def set_ai_analysis
    @ai_analysis = @metric.ai_analyses.find(params[:id])
  end

  def ai_analysis_params
    params.require(:ai_analysis).permit(:analysis_type, :parameters)
  end
end
