require "rails_helper"

RSpec.describe "Управление алертами", type: :system do
  it "показывает список алертов" do
    create(:alert, service: "api-gateway", metric: "latency")

    visit alerts_path

    expect(page).to have_content("api-gateway")
    expect(page).to have_content("latency")
  end

  it "фильтрует алерты по severity" do
    create(:alert, :critical, service: "svc-critical")
    create(:alert, severity: "info", service: "svc-info")

    visit alerts_path
    expect(page).to have_content("svc-critical")
    expect(page).to have_content("svc-info")

    select I18n.t("alerts.severity.critical"), from: "severity"
    click_button I18n.t("alerts.filter_button")

    expect(page).to have_content("svc-critical")
    expect(page).not_to have_content("svc-info")
  end

  it "принимает алерт к сведению кнопкой" do
    alert = create(:alert)

    visit alerts_path
    click_button I18n.t("alerts.actions.acknowledge")

    expect(alert.reload).to be_acknowledged
    expect(page).to have_content(I18n.t("alerts.status.acknowledged"))
  end

  it "решает алерт кнопкой" do
    alert = create(:alert)

    visit alerts_path
    click_button I18n.t("alerts.actions.resolve")

    expect(alert.reload).to be_resolved
  end

  it "показывает карточку алерта" do
    alert = create(:alert, service: "api-gateway", message: "Уникальное сообщение алерта")

    visit alert_path(alert)

    expect(page).to have_content("Уникальное сообщение алерта")
  end

  it "пагинирует таблицу по 20 строк" do
    create_list(:alert, 21)

    visit alerts_path
    expect(page).to have_css("tbody tr", count: 20)

    click_link "2"
    expect(page).to have_css("tbody tr", count: 1)
  end
end
