require "rails_helper"

RSpec.describe DashboardSetting, type: :model do
  describe "валидации" do
    subject { build(:dashboard_setting) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe ".default_settings" do
    it "содержит все обязательные ключи" do
      defaults = described_class.default_settings
      expect(defaults).to include(:refresh_interval, :time_range, :displayed_panels, :layout)
      expect(defaults[:layout][:rows]).to be_an(Array)
    end
  end

  describe "#merged_settings" do
    it "перекрывает значения по умолчанию сохранёнными строковыми ключами (JSON)" do
      # После сериализации в JSON ключи становятся строковыми — merged_settings
      # обязан привести их к символьным, иначе deep_merge не сработает
      setting = create(:dashboard_setting, settings: { "time_range" => "24h" })
      setting.reload

      merged = setting.merged_settings
      expect(merged[:time_range]).to eq("24h")
      expect(merged[:refresh_interval]).to eq("30s") # из дефолтов
    end

    it "возвращает дефолты при пустых настройках" do
      setting = create(:dashboard_setting, settings: nil)
      expect(setting.merged_settings).to eq(described_class.default_settings)
    end
  end

  describe ".current" do
    it "возвращает существующую запись" do
      setting = create(:dashboard_setting, name: "default")
      expect(described_class.current("default")).to eq(setting)
    end

    it "создаёт запись с дефолтами, если её нет" do
      expect {
        described_class.current("default")
      }.to change(described_class, :count).by(1)

      expect(described_class.current("default").settings).to be_present
    end
  end
end
