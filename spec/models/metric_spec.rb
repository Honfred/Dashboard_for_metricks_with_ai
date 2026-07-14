require "rails_helper"

RSpec.describe Metric, type: :model do
  describe "валидации и ассоциации" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:metric_type) }
    it { is_expected.to have_many(:ai_analyses).dependent(:destroy) }

    it do
      is_expected.to define_enum_for(:metric_type)
        .with_values(counter: 0, gauge: 1, histogram: 2, summary: 3)
    end
  end

  describe ".fetch_from_prometheus" do
    it "запрашивает range-данные у Prometheus и возвращает разобранные серии" do
      metric = create(:metric, name: "node_load1")
      stub_prometheus_range

      data = described_class.fetch_from_prometheus(metric.name, "1h")

      expect(data).to be_an(Array)
      expect(data.first[:metric]).to include("job" => "rails_dashboard")
      expect(data.first[:values]).to be_present
    end

    it "для counter-метрики оборачивает запрос в rate()" do
      metric = create(:metric, :counter, name: "http_requests_total")
      # PrometheusService ходит именно на config.prometheus_url
      base = Rails.application.config.prometheus_url
      stub = stub_request(:get, %r{#{Regexp.escape(base)}/api/v1/query_range})
        .with(query: hash_including("query" => "rate(http_requests_total[5m])"))
        .to_return(
          status: 200,
          body: { status: "success", data: { result: [] } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      described_class.fetch_from_prometheus(metric.name)

      expect(stub).to have_been_requested
    end

    it "возвращает пустой массив при ошибке Prometheus" do
      stub_prometheus_down
      expect(described_class.fetch_from_prometheus("node_load1")).to eq([])
    end
  end
end
