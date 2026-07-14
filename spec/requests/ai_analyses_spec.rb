require "rails_helper"

RSpec.describe "AiAnalyses", type: :request do
  let(:metric) { create(:metric, name: "node_load1") }
  let(:ai_base) { ENV["AI_SERVICE_URL"] || "http://localhost:5000" }

  def stub_ai_analysis_types
    stub_request(:get, "#{ai_base}/api/analysis_types")
      .to_return(status: 200, body: { "types" => %w[anomaly_detection trend_prediction] }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  describe "GET /ai_analyses" do
    it "отдаёт общий список анализов" do
      create(:ai_analysis, :completed)
      get ai_analyses_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /ai_analyses/:id (без метрики)" do
    it "редиректит на список с предупреждением" do
      analysis = create(:ai_analysis)
      get ai_analysis_path(analysis)
      expect(response).to redirect_to(ai_analyses_path(locale: I18n.default_locale))
    end
  end

  describe "GET /metrics/:metric_id/ai_analyses/new" do
    it "рендерит форму с доступными типами анализа" do
      stub_ai_analysis_types
      stub_ml_health(ok: true)

      get new_metric_ai_analysis_path(metric)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /metrics/:metric_id/ai_analyses" do
    it "в тестовом режиме сразу завершает анализ с отчётом" do
      expect {
        post metric_ai_analyses_path(metric), params: {
          test_mode: "true",
          ai_analysis: { analysis_type: "anomaly_detection" }
        }
      }.to change(AiAnalysis, :count).by(1)

      analysis = AiAnalysis.last
      expect(response).to redirect_to(metric_ai_analysis_path(metric, analysis, locale: I18n.default_locale))
      expect(analysis.status).to eq("completed")
      expect(analysis.report).to be_present
      expect(analysis.parameters["test_mode"]).to be(true)
    end

    it "в обычном режиме ставит AnalysisJob в очередь" do
      expect {
        post metric_ai_analyses_path(metric), params: {
          ai_analysis: { analysis_type: "trend_prediction" }
        }
      }.to have_enqueued_job(AnalysisJob)

      expect(AiAnalysis.last.status).to eq("pending")
    end

    it "возвращает 422 без типа анализа" do
      stub_ai_analysis_types
      stub_ml_health(ok: true)

      post metric_ai_analyses_path(metric), params: { ai_analysis: { analysis_type: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /metrics/:metric_id/ai_analyses/:id" do
    it "показывает анализ с готовым отчётом" do
      analysis = create(:ai_analysis, :completed, metric: metric)

      get metric_ai_analysis_path(metric, analysis)

      expect(response).to have_http_status(:ok)
    end

    it "отдаёт JSON с анализом и данными" do
      analysis = create(:ai_analysis, :completed, metric: metric)

      get metric_ai_analysis_path(metric, analysis, format: :json)

      body = JSON.parse(response.body)
      expect(body.dig("analysis", "id")).to eq(analysis.id)
      expect(body.dig("data", "insights")).to be_present
    end

    it "выгружает CSV с данными анализа" do
      analysis = create(:ai_analysis, :completed, metric: metric)

      get metric_ai_analysis_path(metric, analysis, format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include(metric.name)
    end

    it "без отчёта запрашивает анализ у AI-сервиса" do
      analysis = create(:ai_analysis, metric: metric)
      stub = stub_request(:post, "#{ai_base}/api/anomaly_detection")
        .to_return(status: 200, body: { "status" => "ok", "insights" => [] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      get metric_ai_analysis_path(metric, analysis)

      expect(response).to have_http_status(:ok)
      expect(stub).to have_been_requested
    end
  end
end
