require "rails_helper"

RSpec.describe "Метрики", type: :system do
  it "показывает список метрик и источники данных Prometheus" do
    create(:metric, name: "node_load1")
    stub_prometheus_query
    stub_prometheus_meta

    visit root_path

    expect(page).to have_content("node_load1")
    expect(page).to have_css(".data-source-item", count: 1)
    expect(page).to have_content("server1")
  end

  it "создаёт метрику через форму" do
    stub_prometheus_query
    stub_prometheus_meta

    visit new_metric_path
    fill_in "metric[name]", with: "custom_gauge"
    fill_in "metric[description]", with: "Описание метрики"
    select "Gauge", from: "metric[metric_type]"

    stub_prometheus_range
    click_button I18n.t("common.save")

    metric = Metric.last
    expect(metric.name).to eq("custom_gauge")
    expect(metric.metric_type).to eq("gauge")
  end

  it "показывает ошибки при невалидной форме" do
    visit new_metric_path
    click_button I18n.t("common.save")

    expect(page).to have_css(".alert-danger")
  end

  it "просматривает метрику с выбором временного интервала" do
    metric = create(:metric, name: "node_load1")
    stub_prometheus_range

    visit metric_path(metric, time_range: "24h")

    expect(page).to have_css("canvas#metrics-chart[data-time-range='24h']")
    # Дропдаун с интервалами предлагает переключение диапазона
    # (href содержит и locale из default_url_options)
    expect(page).to have_link(I18n.t("dashboard.time_range.7d"), href: /time_range=7d/)
  end
end
