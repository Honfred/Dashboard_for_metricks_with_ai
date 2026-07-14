# frozen_string_literal: true

class ReportsController < ApplicationController
  before_action :set_report, only: [ :show, :destroy, :download, :regenerate ]

  # GET /reports
  def index
    @reports = Report.includes(file_attachment: :blob)
                     .by_type(params[:report_type])
                     .not_expired
                     .recent
                     .page(params[:page])
                     .per(20)
  end

  # GET /reports/:id
  def show
    respond_to do |format|
      format.html
      format.json { render json: report_json(@report) }
    end
  end

  # GET /reports/new
  def new
    @report = Report.new
  end

  # POST /reports
  def create
    @report = Report.new(report_params)
    @report.expires_at = 7.days.from_now if @report.expires_at.blank?

    respond_to do |format|
      if @report.save
        format.html { redirect_to reports_path, notice: t("reports.generation_started") }
        format.json { render json: report_json(@report), status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @report.errors }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /reports/:id
  def destroy
    @report.destroy

    respond_to do |format|
      format.html { redirect_to reports_path, notice: t("reports.deleted") }
      format.json { head :no_content }
    end
  end

  # GET /reports/:id/download
  def download
    if @report.file.attached? && @report.completed?
      # Проксируем файл через контроллер, чтобы избежать проблем с внутренним URL MinIO
      send_data @report.file.download,
                filename: @report.file.filename.to_s,
                type: @report.file.content_type,
                disposition: "attachment"
    else
      redirect_to reports_path, alert: t("reports.not_ready")
    end
  end

  # POST /reports/:id/regenerate
  def regenerate
    @report.update!(status: "pending")
    ReportGenerationJob.perform_later(@report.id)

    respond_to do |format|
      format.html { redirect_to reports_path, notice: t("reports.regeneration_started") }
      format.json { render json: report_json(@report) }
    end
  end

  # POST /reports/quick_export
  def quick_export
    report_type = params[:report_type] || "metrics"
    format_type = params[:format_type] || "csv"

    report = Report.create!(
      name: "#{report_type.titleize} Export - #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      report_type: report_type,
      format: format_type,
      parameters: params[:parameters]&.to_unsafe_h || {},
      expires_at: 1.day.from_now
    )

    respond_to do |format|
      format.html { redirect_to reports_path, notice: t("reports.generation_started") }
      format.json { render json: report_json(report), status: :created }
    end
  end

  private

  def set_report
    @report = Report.find(params[:id])
  end

  def report_params
    params.require(:report).permit(
      :name, :report_type, :format, :expires_at,
      parameters: {}
    )
  end

  def report_json(report)
    {
      id: report.id,
      name: report.name,
      report_type: report.report_type,
      format: report.format,
      status: report.status,
      file_url: report.file_url,
      file_size: report.file_size_human,
      generated_at: report.generated_at&.iso8601,
      expires_at: report.expires_at&.iso8601,
      created_at: report.created_at.iso8601
    }
  end
end
