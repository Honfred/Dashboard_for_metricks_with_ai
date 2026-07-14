require "rails_helper"

RSpec.describe "Дашборд", type: :system, js: true do
  before { stub_prometheus_all }

  it "загружает главную страницу со всеми виджетами из настроек" do
    visit dashboard_index_path

    expect(page).to have_css("#metrics-grid")

    DashboardSetting.default_settings[:displayed_panels].each do |panel|
      expect(page).to have_css(".grid-panel[data-panel='#{panel}']")
    end

    # Панель управления дашбордом
    expect(page).to have_css("#time-range")
    expect(page).to have_css("#toggle-edit-mode")
    expect(page).to have_css("canvas", minimum: 4)
  end

  it "подтягивает статусы сервисов из Prometheus через /dashboard/metrics" do
    visit dashboard_index_path

    # dashboard.js делает fetch к /dashboard/metrics и рендерит статусы
    # сервисов из застабленного ответа Prometheus (server1 up)
    expect(page).to have_css(".grid-panel[data-panel='service-health']")
    expect(page).to have_content("server1", wait: 10)
  end
end
