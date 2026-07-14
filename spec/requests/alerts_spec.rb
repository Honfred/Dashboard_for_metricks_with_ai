require "rails_helper"

RSpec.describe "Alerts", type: :request do
  describe "GET /alerts" do
    it "отдаёт список алертов" do
      create(:alert)
      get alerts_path
      expect(response).to have_http_status(:ok)
    end

    it "пагинирует по 20 на страницу" do
      create_list(:alert, 21)
      get alerts_path
      expect(response.body).to include("page=2")
    end
  end

  describe "GET /alerts/active" do
    it "в JSON отдаёт только triggered-алерты" do
      create(:alert)
      create(:alert, :resolved)

      get active_alerts_path(format: :json)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.map { |a| a["status"] }).to all(eq("triggered"))
      expect(body.size).to eq(1)
    end

    it "фильтрует по severity" do
      create(:alert, :critical)
      create(:alert, severity: "info")

      get active_alerts_path(format: :json), params: { severity: "critical" }

      body = JSON.parse(response.body)
      expect(body.map { |a| a["severity"] }).to all(eq("critical"))
    end
  end

  describe "GET /alerts/:id" do
    it "показывает алерт" do
      get alert_path(create(:alert))
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /alerts/:id" do
    it "обновляет статус и редиректит на алерт" do
      alert = create(:alert)
      patch alert_path(alert), params: { alert: { status: "resolved" } }
      expect(response).to redirect_to(alert_path(alert, locale: I18n.default_locale))
      expect(alert.reload).to be_resolved
    end

    it "возвращает 422 при невалидном статусе" do
      alert = create(:alert)
      patch alert_path(alert), params: { alert: { status: "bogus" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /alerts (JSON)" do
    it "создаёт алерт из JSON-пейлоада" do
      expect {
        post alerts_path, params: {
          service: "api-gateway",
          metric: "response_time",
          value: 0.9,
          threshold: 0.5,
          severity: "critical"
        }, as: :json
      }.to change(Alert, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["success"]).to be(true)
      expect(body.dig("alert", "service")).to eq("api-gateway")
    end

    it "обновляет существующий активный алерт вместо дубля" do
      alert = create(:alert)

      expect {
        post alerts_path, params: {
          service: alert.service,
          metric: alert.metric,
          value: 2.5,
          threshold: 1.0,
          severity: "critical"
        }, as: :json
      }.not_to change(Alert, :count)

      expect(response).to have_http_status(:created)
      expect(alert.reload.value).to eq(2.5)
    end

    it "возвращает 422 с ошибками при неполном пейлоаде" do
      post alerts_path, params: { service: "api" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["success"]).to be(false)
      expect(body["errors"]).to be_present
    end
  end

  describe "POST /alerts/:id/resolve" do
    it "решает алерт и редиректит на список (html)" do
      alert = create(:alert)
      post resolve_alert_path(alert)
      expect(response).to redirect_to(alerts_path(locale: I18n.default_locale))
      expect(alert.reload).to be_resolved
    end

    it "отдаёт JSON при формате json" do
      alert = create(:alert)
      post resolve_alert_path(alert, format: :json)
      expect(JSON.parse(response.body)["success"]).to be(true)
    end
  end

  describe "POST /alerts/:id/acknowledge" do
    it "принимает алерт к сведению" do
      alert = create(:alert)
      post acknowledge_alert_path(alert)
      expect(alert.reload).to be_acknowledged
    end
  end
end
