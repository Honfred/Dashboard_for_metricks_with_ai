require "rails_helper"

RSpec.describe MlModelVersion, type: :model do
  describe "валидации" do
    it { is_expected.to validate_presence_of(:model_type) }
    it { is_expected.to validate_inclusion_of(:model_type).in_array(%w[anomaly performance trend]) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[training completed failed deployed deprecated]) }

    it "version уникальна в пределах model_type" do
      create(:ml_model_version, model_type: "anomaly", version: "1.0")
      dup = build(:ml_model_version, model_type: "anomaly", version: "1.0")
      other_type = build(:ml_model_version, model_type: "trend", version: "1.0")

      expect(dup).not_to be_valid
      expect(other_type).to be_valid
    end
  end

  describe "автогенерация версии" do
    it "первая модель типа получает версию 1.0" do
      expect(create(:ml_model_version).version).to eq("1.0")
    end

    it "следующая версия инкрементирует minor" do
      create(:ml_model_version, model_type: "anomaly", version: "1.3")
      expect(create(:ml_model_version, model_type: "anomaly").version).to eq("1.4")
    end

    it "не перезаписывает явно заданную версию" do
      expect(create(:ml_model_version, version: "7.7").version).to eq("7.7")
    end
  end

  describe "#mark_completed!" do
    it "сохраняет метрики, trained_at и статус" do
      model = create(:ml_model_version)
      model.mark_completed!(accuracy: 0.9, f1_score: 0.8, precision: 0.85)

      expect(model.reload).to be_completed
      expect(model.trained_at).to be_present
      expect(model.accuracy).to eq(0.9)
      expect(model.f1_score).to eq(0.8)
      expect(model.metrics["precision"]).to eq(0.85)
    end

    it "выбрасывает nil-метрики" do
      model = create(:ml_model_version)
      model.mark_completed!(accuracy: 0.9, f1_score: nil)
      expect(model.metrics).not_to have_key("f1_score")
    end
  end

  describe "#mark_failed!" do
    it "ставит статус failed и пишет ошибку в metadata" do
      model = create(:ml_model_version)
      model.mark_failed!("не хватило данных")

      expect(model.reload).to be_failed
      expect(model.metadata["error"]).to eq("не хватило данных")
    end
  end

  describe "#deploy!" do
    it "активирует модель и деактивирует прежнюю активную того же типа" do
      old_active = create(:ml_model_version, :deployed, model_type: "anomaly")
      candidate  = create(:ml_model_version, :completed, model_type: "anomaly")

      candidate.deploy!

      expect(candidate.reload).to be_deployed
      expect(candidate.is_active).to be(true)
      expect(candidate.deployed_at).to be_present

      expect(old_active.reload.is_active).to be(false)
      expect(old_active).to be_deprecated
    end

    it "не трогает активные модели другого типа" do
      other = create(:ml_model_version, :deployed, model_type: "trend")
      create(:ml_model_version, :completed, model_type: "anomaly").deploy!
      expect(other.reload.is_active).to be(true)
    end
  end

  describe ".active_model и .latest_model" do
    it ".active_model возвращает активную модель типа" do
      active = create(:ml_model_version, :deployed, model_type: "anomaly")
      create(:ml_model_version, :completed, model_type: "anomaly")

      expect(described_class.active_model("anomaly")).to eq(active)
      expect(described_class.active_model("trend")).to be_nil
    end

    it ".latest_model возвращает свежайшую завершённую" do
      create(:ml_model_version, :completed, model_type: "anomaly", created_at: 2.days.ago)
      newest = create(:ml_model_version, :completed, model_type: "anomaly")

      expect(described_class.latest_model("anomaly")).to eq(newest)
    end
  end

  describe "#display_name" do
    it "использует metric_name из metadata, когда он есть" do
      model = create(:ml_model_version, metadata: { "metric_name" => "node_load1" })
      expect(model.display_name).to eq("node_load1 (anomaly)")
    end

    it "иначе строит имя из типа и версии" do
      model = create(:ml_model_version, version: "2.0")
      expect(model.display_name).to eq("anomaly v2.0")
    end
  end
end
