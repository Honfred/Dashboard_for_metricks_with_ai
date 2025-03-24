class PrometheusController < ApplicationController
  def status
    service = PrometheusService.new
    @targets = service.available_metrics
    
    respond_to do |format|
      format.html
      format.json { render json: @targets }
    end
  end
end 