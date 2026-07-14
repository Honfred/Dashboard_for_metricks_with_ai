require "rails_helper"

RSpec.describe "Prometheus", type: :request do
  describe "GET /prometheus/status" do
    it "отдаёт JSON со списком источников и их статусами" do
      stub_prometheus_query
      stub_prometheus_meta

      get prometheus_status_path(format: :json)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.first).to include("instance" => "server1", "health" => "up")
    end

    it "отдаёт пустой список при недоступном Prometheus" do
      stub_prometheus_down

      get prometheus_status_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end
end
