# frozen_string_literal: true

class MlModelsController < ApplicationController
  before_action :set_model_version, only: [:show, :destroy, :deploy, :download]

  # GET /ml_models
  def index
    @model_versions = MlModelVersion.includes(model_file_attachment: :blob)
                                    .by_type(params[:model_type])
                                    .recent
                                    .page(params[:page])
                                    .per(50)

    @active_models = {
      anomaly: MlModelVersion.active_model('anomaly'),
      performance: MlModelVersion.active_model('performance'),
      trend: MlModelVersion.active_model('trend')
    }
  end

  # GET /ml_models/:id
  def show
    respond_to do |format|
      format.html
      format.json { render json: model_json(@model_version) }
    end
  end

  # DELETE /ml_models/:id
  def destroy
    if @model_version.is_active?
      redirect_to ml_models_path, alert: t('ml_models.cannot_delete_active')
      return
    end

    @model_version.destroy

    respond_to do |format|
      format.html { redirect_to ml_models_path, notice: t('ml_models.deleted') }
      format.json { head :no_content }
    end
  end

  # POST /ml_models/:id/deploy
  def deploy
    unless @model_version.completed?
      redirect_to ml_models_path, alert: t('ml_models.not_completed')
      return
    end

    @model_version.deploy!

    respond_to do |format|
      format.html { redirect_to ml_models_path, notice: t('ml_models.deployed') }
      format.json { render json: model_json(@model_version) }
    end
  end

  # GET /ml_models/:id/download
  def download
    if @model_version.model_file.attached?
      # Проксируем файл через контроллер, чтобы избежать проблем с внутренним URL MinIO
      send_data @model_version.model_file.download,
                filename: @model_version.model_file.filename.to_s,
                type: @model_version.model_file.content_type,
                disposition: 'attachment'
    else
      redirect_to ml_models_path, alert: t('ml_models.file_not_found')
    end
  end

  # POST /ml_models/train
  def train
    model_type = params[:model_type]
    
    unless %w[anomaly performance trend].include?(model_type)
      render json: { error: 'Invalid model type' }, status: :bad_request
      return
    end

    # Создаём новую версию модели
    model_version = MlModelVersion.create!(
      model_type: model_type,
      status: 'training',
      metadata: { requested_by: 'manual', requested_at: Time.current.iso8601 }
    )

    # Запускаем соответствующий job
    case model_type
    when 'anomaly'
      TrainAnomalyModelJob.perform_later(model_version.id)
    when 'performance'
      TrainPerformanceModelJob.perform_later(model_version.id)
    when 'trend'
      TrainTrendModelJob.perform_later(model_version.id)
    end

    respond_to do |format|
      format.html { redirect_to ml_models_path, notice: t('ml_models.training_started') }
      format.json { render json: model_json(model_version), status: :created }
    end
  end

  private

  def set_model_version
    @model_version = MlModelVersion.find(params[:id])
  end

  def model_json(model_version)
    {
      id: model_version.id,
      model_type: model_version.model_type,
      version: model_version.version,
      status: model_version.status,
      is_active: model_version.is_active,
      accuracy: model_version.accuracy,
      f1_score: model_version.f1_score,
      metrics: model_version.metrics,
      model_file_url: model_version.model_file_url,
      trained_at: model_version.trained_at&.iso8601,
      deployed_at: model_version.deployed_at&.iso8601,
      created_at: model_version.created_at.iso8601
    }
  end
end
