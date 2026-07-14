require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /dashboard" do
    it "рендерит дашборд" do
      stub_prometheus_all
      get dashboard_index_path
      expect(response).to have_http_status(:ok)
    end

    it "переживает недоступный Prometheus" do
      stub_prometheus_down
      get dashboard_index_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /dashboard/metrics" do
    it "возвращает JSON со всеми группами метрик" do
      stub_prometheus_all

      get metrics_dashboard_index_path, params: { time_range: "1h" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.keys).to include("services_status", "response_time", "throughput",
                                   "error_rate", "resource_usage")
      expect(body["resource_usage"].keys).to contain_exactly("cpu", "memory")
    end

    it "переводит таймстемпы в миллисекунды" do
      stub_prometheus_query
      stub_prometheus_range(result: [
        { "metric" => {}, "values" => [ [ 1_700_000_000, "42.5" ] ] }
      ])

      get metrics_dashboard_index_path

      body = JSON.parse(response.body)
      time, value = body["response_time"].first["values"].first
      expect(time).to eq(1_700_000_000 * 1000)
      expect(value).to eq(42.5)
    end

    it "превращает NaN от Prometheus в nil (0/0 в PromQL)" do
      stub_prometheus_query
      stub_prometheus_range(result: [
        { "metric" => {}, "values" => [ [ 1_700_000_000, "NaN" ] ] }
      ])

      get metrics_dashboard_index_path

      body = JSON.parse(response.body)
      expect(body["error_rate"].first["values"].first[1]).to be_nil
    end

    it "дедуплицирует сервисы, когда instance скрейпится двумя job" do
      stub_prometheus_range
      stub_prometheus_query(result: [
        { "metric" => { "instance" => "server1", "job" => "node" }, "value" => [ 1, "1" ] },
        { "metric" => { "instance" => "server1", "job" => "app" },  "value" => [ 1, "1" ] }
      ])

      get metrics_dashboard_index_path

      body = JSON.parse(response.body)
      expect(body["services_status"].size).to eq(1)
      expect(body["services_status"].first).to include("name" => "server1", "status" => true)
    end

    it "отдаёт пустые серии при недоступном Prometheus" do
      stub_prometheus_down

      get metrics_dashboard_index_path

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["response_time"]).to eq([])
      expect(body["services_status"]).to eq([])
    end
  end

  describe "GET /dashboard/settings" do
    it "возвращает настройки с дефолтами" do
      get settings_dashboard_index_path

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to be(true)
      expect(body["settings"]).to include("refresh_interval", "time_range", "displayed_panels", "layout")
    end

    it "возвращает сохранённые значения поверх дефолтов" do
      create(:dashboard_setting, settings: { "time_range" => "24h" })

      get settings_dashboard_index_path

      body = JSON.parse(response.body)
      expect(body.dig("settings", "time_range")).to eq("24h")
      expect(body.dig("settings", "refresh_interval")).to eq("30s")
    end
  end

  describe "POST /dashboard/save_settings" do
    it "сохраняет разрешённые настройки, включая вложенный layout" do
      post save_settings_dashboard_index_path, params: {
        settings: {
          refresh_interval: "60s",
          time_range: "3h",
          displayed_panels: [ "service-health", "error-rate" ],
          layout: { rows: [ { panels: [ "service-health" ] }, { panels: [ "error-rate" ] } ] }
        }
      }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["success"]).to be(true)
      expect(body.dig("settings", "refresh_interval")).to eq("60s")

      stored = DashboardSetting.current("default").settings
      expect(stored["time_range"]).to eq("3h")
      expect(stored.dig("layout", "rows"))
        .to eq([ { "panels" => [ "service-health" ] }, { "panels" => [ "error-rate" ] } ])
    end

    it "отбрасывает ключи вне разрешённого списка" do
      post save_settings_dashboard_index_path, params: {
        settings: {
          refresh_interval: "30s",
          malicious_key: "evil",
          layout: { rows: [ { panels: [ "throughput" ], injected: "evil" } ] }
        }
      }, as: :json

      expect(response).to have_http_status(:ok)
      stored = DashboardSetting.current("default").settings
      expect(stored).not_to have_key("malicious_key")
      expect(stored.dig("layout", "rows")).to eq([ { "panels" => [ "throughput" ] } ])
    end

    it "возвращает 422 без параметра settings" do
      post save_settings_dashboard_index_path, params: {}, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /dashboard/ai_overview" do
    it "рендерит сводку с завершёнными анализами" do
      create(:ai_analysis, :completed)
      create(:ai_analysis, :completed, :trend)

      get ai_overview_dashboard_index_path

      expect(response).to have_http_status(:ok)
    end
  end
end
