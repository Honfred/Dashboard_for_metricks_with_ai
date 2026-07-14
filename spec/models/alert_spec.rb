require "rails_helper"

RSpec.describe Alert, type: :model do
  describe "валидации" do
    it { is_expected.to validate_presence_of(:service) }
    it { is_expected.to validate_presence_of(:metric) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_presence_of(:threshold) }
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[triggered resolved acknowledged]) }
    it { is_expected.to validate_inclusion_of(:severity).in_array(%w[info warning critical]) }

    it "создаётся с валидными атрибутами" do
      expect(build(:alert)).to be_valid
    end
  end

  describe "скоупы" do
    let!(:triggered) { create(:alert, service: "web", severity: "critical") }
    let!(:resolved)  { create(:alert, :resolved, service: "db") }

    it ".active возвращает только triggered" do
      expect(described_class.active).to contain_exactly(triggered)
    end

    it ".resolved возвращает только resolved" do
      expect(described_class.resolved).to contain_exactly(resolved)
    end

    it ".by_severity фильтрует по severity" do
      expect(described_class.by_severity("critical")).to contain_exactly(triggered)
    end

    it ".by_severity без значения не фильтрует" do
      expect(described_class.by_severity(nil).count).to eq(2)
    end

    it ".by_service фильтрует по сервису" do
      expect(described_class.by_service("db")).to contain_exactly(resolved)
    end

    it ".recent сортирует по triggered_at по убыванию" do
      old = create(:alert, triggered_at: 2.days.ago)
      expect(described_class.recent.last).to eq(old)
    end

    it ".triggered_for находит активный алерт по service+metric" do
      expect(described_class.triggered_for(triggered.service, triggered.metric)).to contain_exactly(triggered)
      expect(described_class.triggered_for(resolved.service, resolved.metric)).to be_empty
    end
  end

  describe "статусные методы" do
    it "#resolve! переводит в resolved и ставит resolved_at" do
      alert = create(:alert)
      alert.resolve!
      expect(alert.reload).to be_resolved
      expect(alert.resolved_at).to be_present
    end

    it "#acknowledge! переводит в acknowledged" do
      alert = create(:alert)
      alert.acknowledge!
      expect(alert.reload).to be_acknowledged
    end

    it "#trigger! повторно активирует решённый алерт и сбрасывает resolved_at" do
      alert = create(:alert, :resolved)
      alert.trigger!
      expect(alert.reload).to be_active
      expect(alert.resolved_at).to be_nil
    end

    it "#trigger! не трогает уже активный алерт" do
      alert = create(:alert, triggered_at: 1.hour.ago)
      expect { alert.trigger! }.not_to change { alert.reload.triggered_at }
    end
  end

  describe ".trigger_for" do
    it "создаёт новый активный алерт" do
      expect {
        described_class.trigger_for("api", "latency", 2.0, 1.0, "critical")
      }.to change(described_class, :count).by(1)

      alert = described_class.last
      expect(alert).to be_active
      expect(alert.severity).to eq("critical")
      expect(alert.message).to include("api")
    end

    it "обновляет существующий активный алерт вместо дубля" do
      existing = create(:alert, service: "api", metric: "latency", value: 1.5)

      expect {
        described_class.trigger_for("api", "latency", 2.5, 1.0)
      }.not_to change(described_class, :count)

      expect(existing.reload.value).to eq(2.5)
    end

    it "использует переданное сообщение, если оно есть" do
      alert = described_class.trigger_for("api", "latency", 2.0, 1.0, "warning", "своё сообщение")
      expect(alert.message).to eq("своё сообщение")
    end
  end
end
