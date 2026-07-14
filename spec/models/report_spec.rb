require "rails_helper"

RSpec.describe Report, type: :model do
  describe "валидации" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:report_type).in_array(%w[metrics alerts ai_analysis dashboard combined]) }
    it { is_expected.to validate_inclusion_of(:format).in_array(%w[pdf csv json]) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[pending processing completed failed]) }
  end

  describe "генерация после создания" do
    it "ставит ReportGenerationJob в очередь" do
      expect {
        create(:report)
      }.to have_enqueued_job(ReportGenerationJob)
    end
  end

  describe "скоупы" do
    it ".not_expired отдаёт неистёкшие и бессрочные" do
      fresh    = create(:report, expires_at: 1.day.from_now)
      eternal  = create(:report, expires_at: nil)
      create(:report, :expired)

      expect(described_class.not_expired).to contain_exactly(fresh, eternal)
    end

    it ".by_type фильтрует по типу отчёта" do
      metrics_report = create(:report, report_type: "metrics")
      create(:report, report_type: "alerts")

      expect(described_class.by_type("metrics")).to contain_exactly(metrics_report)
    end
  end

  describe "#expired?" do
    it "true только для отчёта с истёкшим сроком" do
      expect(create(:report, :expired)).to be_expired
      expect(create(:report, expires_at: 1.day.from_now)).not_to be_expired
      expect(create(:report, expires_at: nil)).not_to be_expired
    end
  end

  describe "статусные переходы" do
    it "#mark_processing! / #mark_completed! / #mark_failed!" do
      report = create(:report)

      report.mark_processing!
      expect(report.reload).to be_processing

      report.mark_completed!
      expect(report.reload).to be_completed
      expect(report.generated_at).to be_present

      report.mark_failed!("нет данных")
      expect(report.reload).to be_failed
      expect(report.metadata["error"]).to eq("нет данных")
    end
  end

  describe "работа с файлом" do
    it "методы файла возвращают nil без вложения" do
      report = create(:report)
      expect(report.file_url).to be_nil
      expect(report.file_size).to be_nil
      expect(report.file_size_human).to be_nil
    end

    it "отдаёт url и размер при вложенном файле" do
      report = create(:report, :completed)
      expect(report.file_url).to include("rails/active_storage")
      expect(report.file_size).to be > 0
      expect(report.file_size_human).to be_present
    end
  end
end
