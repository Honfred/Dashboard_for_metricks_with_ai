class AiAnalysesController < ApplicationController
  before_action :set_metric, except: [:index]
  before_action :set_ai_analysis, only: [:show]

  def index
    @ai_analyses = AiAnalysis.includes(:metric).order(created_at: :desc)
  end

  def show
    # Получаем данные анализа из отчета, если он есть
    if @ai_analysis.report.present?
      @analysis_data = @ai_analysis.report
    else
      # Проверяем, не был ли анализ создан в тестовом режиме
      test_mode = ActiveModel::Type::Boolean.new.cast(@ai_analysis.parameters.try(:[], "test_mode"))
      
      if test_mode
        # Для тестовых анализов запускаем TestAnalysisJob напрямую, если отчёт отсутствует
        Rails.logger.info("AI Analyses Controller: Re-running TestAnalysisJob for analysis #{@ai_analysis.id}")
        test_job = TestAnalysisJob.new
        
        # Получаем тестовый отчет и результаты для обновления анализа
        test_report = test_job.generate_test_report_for(@ai_analysis.analysis_type, @ai_analysis.metric.name)
        test_result = test_job.generate_test_result_for(@ai_analysis.analysis_type)
        
        # Обновляем и отчет, и результаты анализа
        @ai_analysis.update(
          status: 'completed',
          report: test_report,
          results: test_result,
          completed_at: Time.current
        )
        
        @analysis_data = test_report
      else
        # Только для нетестовых анализов пытаемся обратиться к ML-сервису
        @analysis_data = AiAnalysis.fetch_latest_analysis(@metric.id, @ai_analysis.analysis_type)
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: { analysis: @ai_analysis, data: @analysis_data } }
      format.csv { send_data generate_csv, filename: "analysis_#{@ai_analysis.id}_#{Date.current}.csv", type: 'text/csv; charset=utf-8' }
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
    # Добавляем параметр test_mode к остальным параметрам анализа
    parameters = ai_analysis_params[:parameters].present? ? JSON.parse(ai_analysis_params[:parameters]) : {}
    
    # Сохраняем информацию о тестовом режиме в параметрах анализа
    test_mode = params[:test_mode].present? && params[:test_mode] == "true"
    if test_mode
      parameters["test_mode"] = true
    end
    
    # Создаем анализ с обновленными параметрами
    @ai_analysis = @metric.ai_analyses.new(ai_analysis_params.merge(
      status: 'pending',
      parameters: parameters
    ))

    if @ai_analysis.save
      Rails.logger.info("AI Analyses Controller: Scheduling analysis job for analysis #{@ai_analysis.id}")
      
      # В тестовом режиме сразу генерируем и сохраняем тестовые данные
      if test_mode
        Rails.logger.info("AI Analyses Controller: Using test mode for analysis #{@ai_analysis.id}")
        
        # Создаем экземпляр тестового задания
        test_job = TestAnalysisJob.new
        
        # Генерируем тестовые результаты и отчет
        test_result = test_job.generate_test_result_for(@ai_analysis.analysis_type)
        test_report = test_job.generate_test_report_for(@ai_analysis.analysis_type, @metric.name)
        
        # Сохраняем данные в базе данных
        @ai_analysis.update(
          status: 'completed',
          results: test_result,
          report: test_report,
          completed_at: Time.current
        )
      else
        # Запускаем реальный анализ асинхронно, передаём локаль
        AnalysisJob.perform_later(@ai_analysis.id, I18n.locale.to_s)
      end
      
      redirect_to [@metric, @ai_analysis], notice: t('ai_analysis.messages.started')
    else
      @available_analysis_types = AiService.new.available_analysis_types
      @ml_service_available = MlService.check_connection
      render :new, status: :unprocessable_entity
    end
  end

  private

  def generate_csv
    require 'csv'
    
    CSV.generate(headers: true, col_sep: ',') do |csv|
      # Заголовок с информацией об анализе
      csv << [t('ai_analysis.csv.analysis_info')]
      csv << [t('ai_analysis.csv.metric'), @metric.name]
      csv << [t('ai_analysis.csv.analysis_type'), t("ai_analysis.types.#{@ai_analysis.analysis_type}")]
      csv << [t('ai_analysis.csv.status'), t("ai_analysis.status.#{@ai_analysis.status}")]
      csv << [t('ai_analysis.csv.created_at'), @ai_analysis.created_at&.strftime('%Y-%m-%d %H:%M:%S')]
      csv << [t('ai_analysis.csv.completed_at'), @ai_analysis.completed_at&.strftime('%Y-%m-%d %H:%M:%S')]
      csv << []
      
      # Статистика
      if @analysis_data.present?
        stats = @analysis_data[:statistics] || @analysis_data["statistics"]
        if stats.present?
          csv << [t('ai_analysis.csv.statistics')]
          stats.each do |key, value|
            csv << [key, value]
          end
          csv << []
        end
        
        # Выводы (Insights)
        insights = @analysis_data[:insights] || @analysis_data["insights"]
        if insights.present? && insights.any?
          csv << [t('ai_analysis.csv.insights')]
          csv << [t('ai_analysis.csv.title'), t('ai_analysis.csv.description'), t('ai_analysis.csv.severity'), t('ai_analysis.csv.recommendation')]
          insights.each do |insight|
            csv << [
              insight["title"] || insight[:title],
              insight["description"] || insight[:description],
              insight["severity"] || insight[:severity],
              insight["recommendation"] || insight[:recommendation]
            ]
          end
          csv << []
        end
        
        # События
        events = @analysis_data[:events] || @analysis_data["events"]
        if events.present? && events.any?
          csv << [t('ai_analysis.csv.events')]
          csv << [t('ai_analysis.csv.timestamp'), t('ai_analysis.csv.type'), t('ai_analysis.csv.value'), t('ai_analysis.csv.deviation'), t('ai_analysis.csv.description')]
          events.each do |event|
            timestamp = event["timestamp"] || event[:timestamp]
            formatted_time = timestamp.is_a?(Integer) ? Time.at(timestamp).strftime('%Y-%m-%d %H:%M:%S') : timestamp
            csv << [
              formatted_time,
              event["type"] || event[:type],
              event["value"] || event[:value],
              event["deviation"] || event[:deviation],
              event["description"] || event[:description]
            ]
          end
          csv << []
        end
        
        # Данные графика
        chart_data = @analysis_data[:chart_data] || @analysis_data["chart_data"]
        if chart_data.present?
          csv << [t('ai_analysis.csv.chart_data')]
          csv << [t('ai_analysis.csv.timestamp'), t('ai_analysis.csv.value')]
          chart_data.each do |point|
            timestamp = point["timestamp"] || point[:timestamp] || point[0]
            value = point["value"] || point[:value] || point[1]
            formatted_time = timestamp.is_a?(Integer) ? Time.at(timestamp).strftime('%Y-%m-%d %H:%M:%S') : timestamp
            csv << [formatted_time, value]
          end
        end
      end
    end
  end

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
