# frozen_string_literal: true

class ReportExportService
  attr_reader :report

  def initialize(report)
    @report = report
  end

  def generate!
    report.mark_processing!

    content = case report.format
    when "pdf" then generate_pdf
    when "csv" then generate_csv
    when "json" then generate_json
    else raise "Unknown format: #{report.format}"
    end

    attach_file(content)
    report.mark_completed!
    report
  rescue StandardError => e
    report.mark_failed!(e.message)
    Rails.logger.error("Report generation failed: #{e.message}")
    raise
  end

  private

  def generate_pdf
    require "prawn"
    require "prawn/table"

    pdf = Prawn::Document.new(page_size: "A4", margin: 40)

    # Регистрация UTF-8 шрифтов для поддержки кириллицы
    font_path = Rails.root.join("app", "assets", "fonts")
    pdf.font_families.update(
      "DejaVuSans" => {
        normal: font_path.join("DejaVuSans.ttf").to_s,
        bold: font_path.join("DejaVuSans-Bold.ttf").to_s,
        italic: font_path.join("DejaVuSans-Oblique.ttf").to_s,
        bold_italic: font_path.join("DejaVuSans-BoldOblique.ttf").to_s
      }
    )
    pdf.font "DejaVuSans"

    # Заголовок
    pdf.font_size(20) { pdf.text report.name, style: :bold }
    pdf.move_down 10
    pdf.text "#{I18n.t('reports.generated_at')}: #{Time.current.strftime('%Y-%m-%d %H:%M')}"
    pdf.move_down 20

    # Контент в зависимости от типа отчёта
    case report.report_type
    when "metrics"
      generate_metrics_pdf(pdf)
    when "alerts"
      generate_alerts_pdf(pdf)
    when "ai_analysis"
      generate_ai_analysis_pdf(pdf)
    when "dashboard"
      generate_dashboard_pdf(pdf)
    when "combined"
      generate_combined_pdf(pdf)
    end

    pdf.render
  end

  def generate_csv
    require "csv"

    CSV.generate(headers: true) do |csv|
      case report.report_type
      when "metrics"
        generate_metrics_csv(csv)
      when "alerts"
        generate_alerts_csv(csv)
      when "ai_analysis"
        generate_ai_analysis_csv(csv)
      else
        generate_metrics_csv(csv)
      end
    end
  end

  def generate_json
    data = case report.report_type
    when "metrics"
             metrics_data
    when "alerts"
             alerts_data
    when "ai_analysis"
             ai_analysis_data
    when "dashboard"
             dashboard_data
    when "combined"
             combined_data
    end

    JSON.pretty_generate(data)
  end

  # PDF generators
  def generate_metrics_pdf(pdf)
    metrics = fetch_metrics

    pdf.font_size(16) { pdf.text I18n.t("reports.metrics_section"), style: :bold }
    pdf.move_down 10

    if metrics.any?
      table_data = [ [ I18n.t("metrics.name"), I18n.t("metrics.type"),
                     I18n.t("metrics.unit"), I18n.t("metrics.description") ] ]

      metrics.each do |metric|
        table_data << [ metric.name, metric.metric_type,
                       metric.unit || "-", metric.description.to_s.truncate(50) ]
      end

      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = "CCCCCC"
      end
    else
      pdf.text I18n.t("reports.no_data")
    end
  end

  def generate_alerts_pdf(pdf)
    alerts = fetch_alerts

    pdf.font_size(16) { pdf.text I18n.t("reports.alerts_section"), style: :bold }
    pdf.move_down 10

    if alerts.any?
      table_data = [ [ I18n.t("alerts.service"), I18n.t("alerts.metric"),
                     I18n.t("alerts.severity_field"), I18n.t("alerts.table.status"),
                     I18n.t("alerts.triggered_at") ] ]

      alerts.each do |alert|
        table_data << [ alert.service.to_s, alert.metric.to_s, alert.severity.to_s,
                       alert.status.to_s, alert.triggered_at&.strftime("%Y-%m-%d %H:%M") ]
      end

      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = "CCCCCC"
      end
    else
      pdf.text I18n.t("reports.no_data")
    end
  end

  def generate_ai_analysis_pdf(pdf)
    analyses = fetch_ai_analyses

    pdf.font_size(16) { pdf.text I18n.t("reports.ai_analysis_section"), style: :bold }
    pdf.move_down 10

    analyses.each do |analysis|
      pdf.font_size(12) { pdf.text "#{analysis.analysis_type.titleize} - #{analysis.created_at.strftime('%Y-%m-%d')}", style: :bold }
      pdf.move_down 5
      pdf.text "Status: #{analysis.status}"

      if analysis.report.present?
        pdf.text "Insights: #{analysis.insights_count}"
        pdf.text "High severity: #{analysis.high_severity_insights_count}"
      end

      pdf.move_down 15
    end
  end

  def generate_dashboard_pdf(pdf)
    generate_metrics_pdf(pdf)
    pdf.move_down 20
    generate_alerts_pdf(pdf)
  end

  def generate_combined_pdf(pdf)
    generate_metrics_pdf(pdf)
    pdf.start_new_page
    generate_alerts_pdf(pdf)
    pdf.start_new_page
    generate_ai_analysis_pdf(pdf)
  end

  # CSV generators
  def generate_metrics_csv(csv)
    csv << [ "ID", "Name", "Display Name", "Type", "Unit", "Description", "Created At" ]

    fetch_metrics.each do |metric|
      csv << [ metric.id, metric.name, metric.display_name, metric.metric_type,
              metric.unit, metric.description, metric.created_at.iso8601 ]
    end
  end

  def generate_alerts_csv(csv)
    csv << [ "ID", "Service", "Metric", "Value", "Threshold", "Severity",
            "Status", "Message", "Triggered At", "Resolved At" ]

    fetch_alerts.each do |alert|
      csv << [ alert.id, alert.service, alert.metric, alert.value,
              alert.threshold, alert.severity, alert.status, alert.message,
              alert.triggered_at&.iso8601, alert.resolved_at&.iso8601 ]
    end
  end

  def generate_ai_analysis_csv(csv)
    csv << [ "ID", "Metric ID", "Analysis Type", "Status", "Insights Count",
            "High Severity Count", "Created At", "Completed At" ]

    fetch_ai_analyses.each do |analysis|
      csv << [ analysis.id, analysis.metric_id, analysis.analysis_type,
              analysis.status, analysis.insights_count,
              analysis.high_severity_insights_count,
              analysis.created_at.iso8601, analysis.completed_at&.iso8601 ]
    end
  end

  # JSON data generators
  def metrics_data
    {
      report_name: report.name,
      generated_at: Time.current.iso8601,
      metrics: fetch_metrics.map do |m|
        {
          id: m.id,
          name: m.name,
          display_name: m.display_name,
          metric_type: m.metric_type,
          unit: m.unit,
          description: m.description,
          created_at: m.created_at.iso8601
        }
      end
    }
  end

  def alerts_data
    {
      report_name: report.name,
      generated_at: Time.current.iso8601,
      alerts: fetch_alerts.map do |a|
        {
          id: a.id,
          service: a.service,
          metric: a.metric,
          value: a.value,
          threshold: a.threshold,
          severity: a.severity,
          status: a.status,
          message: a.message,
          triggered_at: a.triggered_at&.iso8601,
          resolved_at: a.resolved_at&.iso8601
        }
      end
    }
  end

  def ai_analysis_data
    {
      report_name: report.name,
      generated_at: Time.current.iso8601,
      analyses: fetch_ai_analyses.map do |a|
        {
          id: a.id,
          metric_id: a.metric_id,
          analysis_type: a.analysis_type,
          status: a.status,
          report: a.report,
          created_at: a.created_at.iso8601,
          completed_at: a.completed_at&.iso8601
        }
      end
    }
  end

  def dashboard_data
    {
      report_name: report.name,
      generated_at: Time.current.iso8601,
      metrics: metrics_data[:metrics],
      alerts: alerts_data[:alerts]
    }
  end

  def combined_data
    {
      report_name: report.name,
      generated_at: Time.current.iso8601,
      metrics: metrics_data[:metrics],
      alerts: alerts_data[:alerts],
      ai_analyses: ai_analysis_data[:analyses]
    }
  end

  # Data fetchers
  def fetch_metrics
    scope = Metric.all

    if report.parameters["start_date"].present? && report.parameters["start_date"].to_s.strip.present?
      scope = scope.where("created_at >= ?", report.parameters["start_date"])
    end

    if report.parameters["end_date"].present? && report.parameters["end_date"].to_s.strip.present?
      scope = scope.where("created_at <= ?", Date.parse(report.parameters["end_date"]).end_of_day)
    end

    if report.parameters["metric_type"].present?
      scope = scope.where(metric_type: report.parameters["metric_type"])
    end

    scope.order(created_at: :desc).limit(report.parameters["limit"] || 1000)
  end

  def fetch_alerts
    scope = Alert.all

    if report.parameters["start_date"].present? && report.parameters["start_date"].to_s.strip.present?
      scope = scope.where("triggered_at >= ?", report.parameters["start_date"])
    end

    if report.parameters["end_date"].present? && report.parameters["end_date"].to_s.strip.present?
      scope = scope.where("triggered_at <= ?", Date.parse(report.parameters["end_date"]).end_of_day)
    end

    if report.parameters["severity"].present?
      scope = scope.where(severity: report.parameters["severity"])
    end

    if report.parameters["status"].present?
      scope = scope.where(status: report.parameters["status"])
    end

    scope.order(triggered_at: :desc).limit(report.parameters["limit"] || 1000)
  end

  def fetch_ai_analyses
    scope = AiAnalysis.all

    if report.parameters["start_date"].present?
      scope = scope.where("created_at >= ?", report.parameters["start_date"])
    end

    if report.parameters["end_date"].present?
      scope = scope.where("created_at <= ?", report.parameters["end_date"])
    end

    if report.parameters["analysis_type"].present?
      scope = scope.where(analysis_type: report.parameters["analysis_type"])
    end

    scope.order(created_at: :desc).limit(report.parameters["limit"] || 100)
  end

  def attach_file(content)
    filename = "#{report.report_type}_#{report.id}_#{Time.current.to_i}.#{report.format}"
    content_type = case report.format
    when "pdf" then "application/pdf"
    when "csv" then "text/csv"
    when "json" then "application/json"
    end

    report.file.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )
  end
end
