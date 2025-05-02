class AiAnalysesController < ApplicationController
  before_action :set_metric, except: [:index]
  before_action :set_ai_analysis, only: [:show]

  def index
    @ai_analyses = AiAnalysis.includes(:metric).order(created_at: :desc)
  end

  def show
    # Получаем данные анализа из отчета, если он есть, иначе запрашиваем через AI Service
    @analysis_data = @ai_analysis.report.present? ? @ai_analysis.report : AiAnalysis.fetch_latest_analysis(@metric.id, @ai_analysis.analysis_type)

    respond_to do |format|
      format.html
      format.json { render json: { analysis: @ai_analysis, data: @analysis_data } }
    end
  end

  def new
    @ai_analysis = @metric.ai_analyses.new
    
    # Применяем тип анализа из параметров, если он предоставлен
    if params[:analysis_type].present? && AiAnalysis.analysis_types.keys.include?(params[:analysis_type])
      @ai_analysis.analysis_type = params[:analysis_type]
    end
    
    @available_analysis_types = AiService.new.available_analysis_types
    
    # Проверяем доступность ML-сервиса
    @ml_service_available = MlService.check_connection
  end

  def create
    @ai_analysis = @metric.ai_analyses.new(ai_analysis_params.merge(status: 'pending'))

    if @ai_analysis.save
      # Запускаем анализ асинхронно
      Rails.logger.info("AI Analyses Controller: Scheduling AnalysisJob for analysis #{@ai_analysis.id}")
      
      # Проверяем параметр для тестового режима
      if params[:test_mode].present? && params[:test_mode] == "true"
        Rails.logger.info("AI Analyses Controller: Using test mode for analysis #{@ai_analysis.id}")
        TestAnalysisJob.perform_later(@ai_analysis.id)
      else
        AnalysisJob.perform_later(@ai_analysis.id)
      end
      
      redirect_to [@metric, @ai_analysis], notice: "Анализ успешно запущен."
    else
      @available_analysis_types = AiService.new.available_analysis_types
      @ml_service_available = MlService.check_connection
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
