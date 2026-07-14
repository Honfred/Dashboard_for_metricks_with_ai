require "rails_helper"

RSpec.describe "Reports", type: :request do
  describe "GET /reports" do
    it "отдаёт список без истёкших отчётов" do
      create(:report)
      create(:report, :expired, name: "Просроченный отчёт")

      get reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Просроченный отчёт")
    end

    it "фильтрует по типу отчёта" do
      create(:report, report_type: "alerts", name: "Отчёт по алертам")
      create(:report, report_type: "metrics", name: "Отчёт по метрикам")

      get reports_path, params: { report_type: "alerts" }

      expect(response.body).to include("Отчёт по алертам")
      expect(response.body).not_to include("Отчёт по метрикам")
    end
  end

  describe "POST /reports" do
    it "создаёт отчёт, ставит генерацию в очередь и задаёт срок жизни" do
      expect {
        post reports_path, params: {
          report: { name: "Новый отчёт", report_type: "metrics", format: "pdf" }
        }
      }.to change(Report, :count).by(1).and have_enqueued_job(ReportGenerationJob)

      report = Report.last
      expect(response).to redirect_to(reports_path(locale: I18n.default_locale))
      expect(report.expires_at).to be_present
    end

    it "отдаёт JSON со статусом 201" do
      post reports_path, params: {
        report: { name: "JSON отчёт", report_type: "alerts", format: "csv" }
      }, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("JSON отчёт")
      expect(body["status"]).to eq("pending")
    end

    it "возвращает 422 при невалидных параметрах" do
      post reports_path, params: { report: { name: "", report_type: "bogus", format: "pdf" } },
                         as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end
  end

  describe "GET /reports/:id" do
    it "отдаёт JSON отчёта" do
      report = create(:report, :completed)

      get report_path(report, format: :json)

      body = JSON.parse(response.body)
      expect(body["id"]).to eq(report.id)
      expect(body["file_url"]).to be_present
    end
  end

  describe "GET /reports/:id/download" do
    it "отдаёт файл готового отчёта" do
      report = create(:report, :completed)

      get download_report_path(report)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.body).to include("id,name")
    end

    it "редиректит, если отчёт ещё не готов" do
      report = create(:report)

      get download_report_path(report)

      expect(response).to redirect_to(reports_path(locale: I18n.default_locale))
    end
  end

  describe "POST /reports/:id/regenerate" do
    it "сбрасывает статус и заново ставит джобу" do
      report = create(:report, :completed)
      clear_enqueued_jobs

      expect {
        post regenerate_report_path(report)
      }.to have_enqueued_job(ReportGenerationJob).with(report.id)

      expect(report.reload.status).to eq("pending")
    end
  end

  describe "POST /reports/quick_export" do
    it "создаёт отчёт с коротким сроком жизни" do
      expect {
        post quick_export_reports_path, params: { report_type: "alerts", format_type: "csv" },
                                        as: :json
      }.to change(Report, :count).by(1)

      expect(response).to have_http_status(:created)
      report = Report.last
      expect(report.report_type).to eq("alerts")
      expect(report.format).to eq("csv")
      expect(report.expires_at).to be <= 1.day.from_now
    end
  end

  describe "DELETE /reports/:id" do
    it "удаляет отчёт" do
      report = create(:report)
      expect { delete report_path(report) }.to change(Report, :count).by(-1)
    end
  end
end
