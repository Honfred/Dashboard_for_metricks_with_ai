require "rails_helper"

RSpec.describe AiAnalysis, type: :model do
  describe "валидации и ассоциации" do
    it { is_expected.to belong_to(:metric) }
    it { is_expected.to validate_presence_of(:analysis_type) }

    it do
      is_expected.to define_enum_for(:analysis_type)
        .with_values(anomaly_detection: 0, trend_prediction: 1, performance_insight: 2)
    end

    it do
      is_expected.to define_enum_for(:status)
        .with_values(pending: "pending", processing: "processing",
                     completed: "completed", failed: "failed")
        .backed_by_column_of_type(:string)
    end

    it "по умолчанию статус pending" do
      expect(described_class.new.status).to eq("pending")
    end
  end

  describe "скоупы" do
    let!(:completed_anomaly) { create(:ai_analysis, :completed) }
    let!(:completed_trend)   { create(:ai_analysis, :completed, :trend) }
    let!(:pending_analysis)  { create(:ai_analysis) }

    it ".completed возвращает только завершённые" do
      expect(described_class.completed).to contain_exactly(completed_anomaly, completed_trend)
    end

    it ".anomaly_completed пересекает тип и статус" do
      expect(described_class.anomaly_completed).to contain_exactly(completed_anomaly)
    end

    it ".trend_completed пересекает тип и статус" do
      expect(described_class.trend_completed).to contain_exactly(completed_trend)
    end

    it ".recent сортирует по created_at по убыванию" do
      old = create(:ai_analysis, created_at: 2.days.ago)
      expect(described_class.recent.last).to eq(old)
    end
  end

  describe "#completed?" do
    it "true только при статусе completed и заполненном completed_at" do
      expect(create(:ai_analysis, :completed)).to be_completed
      expect(create(:ai_analysis, status: "completed", completed_at: nil)).not_to be_completed
      expect(create(:ai_analysis)).not_to be_completed
    end
  end

  describe "#processing_time" do
    it "возвращает длительность анализа в секундах" do
      analysis = create(:ai_analysis, created_at: Time.current)
      analysis.update!(status: "completed", completed_at: analysis.created_at + 90.seconds)
      expect(analysis.processing_time).to eq(90)
    end

    it "nil, если анализ не завершён" do
      expect(create(:ai_analysis).processing_time).to be_nil
    end
  end

  describe "подсчёт инсайтов" do
    it "#insights_count считает инсайты из report" do
      expect(create(:ai_analysis, :completed).insights_count).to eq(2)
    end

    it "#high_severity_insights_count считает только severity=high" do
      expect(create(:ai_analysis, :completed).high_severity_insights_count).to eq(1)
    end

    it "оба метода возвращают 0 без report" do
      analysis = create(:ai_analysis)
      expect(analysis.insights_count).to eq(0)
      expect(analysis.high_severity_insights_count).to eq(0)
    end
  end
end
