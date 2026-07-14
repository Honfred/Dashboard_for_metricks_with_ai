require "rails_helper"

RSpec.describe "Отчёты", type: :system do
  it "генерирует CSV-отчёт через форму и скачивает его" do
    create(:alert, service: "api-gateway")

    visit new_report_path
    fill_in "report[name]", with: "Отчёт по алертам"
    select I18n.t("reports.types.alerts"), from: "report[report_type]"
    select "CSV", from: "report[format]"

    perform_enqueued_jobs do
      click_button I18n.t("reports.generate")
    end

    report = Report.last
    expect(report.reload).to be_completed
    expect(report.file).to be_attached

    # На списке отчётов есть ссылка на скачивание
    visit reports_path
    expect(page).to have_css("a[href*='#{download_report_path(report)}']")

    # Скачивание отдаёт CSV с данными
    visit download_report_path(report)
    expect(page.body).to include("api-gateway")
  end

  it "генерирует PDF-отчёт по метрикам" do
    create(:metric)
    report = nil

    perform_enqueued_jobs do
      report = create(:report, :pdf, report_type: "metrics")
    end

    expect(report.reload).to be_completed
    expect(report.file).to be_attached
    expect(report.file.content_type).to eq("application/pdf")
    expect(report.file.download).to start_with("%PDF")
  end

  it "показывает статус pending до генерации" do
    create(:report, name: "Ожидающий отчёт")

    visit reports_path

    expect(page).to have_content("Ожидающий отчёт")
    expect(page).to have_content(I18n.t("reports.statuses.pending"))
  end
end
