class AlertsController < ApplicationController
  before_action :set_alert, only: [:show, :update, :resolve, :acknowledge]

  def index
    @alerts = Alert.recent
               .by_severity(params[:severity])
               .by_service(params[:service])
               .page(params[:page]).per(20)
  end

  def active
    @alerts = Alert.active
               .by_severity(params[:severity])
               .by_service(params[:service])
               .recent
               .page(params[:page]).per(20)
    
    render :index
  end

  def show
  end

  def update
    if @alert.update(alert_params)
      redirect_to @alert, notice: 'Оповещение успешно обновлено.'
    else
      render :show
    end
  end
  
  def resolve
    @alert.resolve!
    respond_to do |format|
      format.html { redirect_to alerts_path, notice: 'Оповещение отмечено как решенное.' }
      format.json { render json: { success: true, alert: @alert } }
    end
  end
  
  def acknowledge
    @alert.acknowledge!
    respond_to do |format|
      format.html { redirect_to alerts_path, notice: 'Оповещение принято к сведению.' }
      format.json { render json: { success: true, alert: @alert } }
    end
  end
  
  private
  
  def set_alert
    @alert = Alert.find(params[:id])
  end
  
  def alert_params
    params.require(:alert).permit(:status, :message, :severity)
  end
end
