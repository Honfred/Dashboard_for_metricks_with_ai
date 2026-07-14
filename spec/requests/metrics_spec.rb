require "rails_helper"

RSpec.describe "Metrics", type: :request do
  describe "GET / (список метрик)" do
    it "рендерит индекс с доступными источниками Prometheus" do
      create(:metric)
      stub_prometheus_query
      stub_prometheus_meta

      get root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /metrics (Prometheus exposition)" do
    it "отдаёт метрики приложения в текстовом формате без CSRF-проверки" do
      get "/metrics"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to start_with("text/plain")
    end
  end

  describe "GET /metrics/:id" do
    it "показывает метрику с данными из Prometheus" do
      metric = create(:metric, name: "node_load1")
      stub_prometheus_range

      get metric_path(metric)

      expect(response).to have_http_status(:ok)
    end

    it "отдаёт JSON с метрикой и данными" do
      metric = create(:metric, name: "node_load1")
      stub_prometheus_range

      get metric_path(metric, format: :json), params: { time_range: "3h" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("metric", "id")).to eq(metric.id)
      expect(body["data"]).to be_an(Array)
      expect(body["data"].first["values"]).to be_present
    end

    it "отдаёт пустые данные, когда Prometheus ничего не вернул" do
      metric = create(:metric, name: "unknown_metric")
      stub_prometheus_range(result: [])

      get metric_path(metric, format: :json)

      body = JSON.parse(response.body)
      expect(body["data"]).to eq([])
    end
  end

  describe "POST /metrics" do
    it "создаёт метрику и редиректит на неё" do
      expect {
        post metrics_path, params: { metric: { name: "new_metric", metric_type: "gauge" } }
      }.to change(Metric, :count).by(1)

      expect(response).to redirect_to(metric_path(Metric.last, locale: I18n.default_locale))
    end

    it "возвращает 422 при невалидных параметрах" do
      post metrics_path, params: { metric: { name: "", metric_type: "gauge" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /metrics/:id" do
    it "обновляет метрику" do
      metric = create(:metric)
      patch metric_path(metric), params: { metric: { description: "новое описание" } }
      expect(metric.reload.description).to eq("новое описание")
    end

    it "возвращает 422 при невалидных параметрах" do
      metric = create(:metric)
      patch metric_path(metric), params: { metric: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /metrics/:id" do
    it "удаляет метрику вместе с анализами" do
      metric = create(:metric)
      create(:ai_analysis, metric: metric)

      expect {
        delete metric_path(metric)
      }.to change(Metric, :count).by(-1).and change(AiAnalysis, :count).by(-1)
    end
  end

  describe "GET /check_ml_service" do
    it "ok, когда ML-сервис отвечает" do
      stub_ml_health(ok: true)
      get check_ml_service_path
      expect(JSON.parse(response.body)["status"]).to eq("ok")
    end

    it "error, когда ML-сервис недоступен" do
      stub_ml_health(ok: false)
      get check_ml_service_path
      expect(JSON.parse(response.body)["status"]).to eq("error")
    end
  end
end
