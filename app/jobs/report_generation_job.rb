# frozen_string_literal: true

class ReportGenerationJob < ApplicationJob
  queue_as :default

  def perform(report_id)
    report = Report.find(report_id)
    ReportExportService.new(report).generate!
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("Report #{report_id} not found")
  rescue StandardError => e
    Rails.logger.error("Report generation failed for #{report_id}: #{e.message}")
    raise
  end
end
