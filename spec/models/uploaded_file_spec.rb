require "rails_helper"

RSpec.describe UploadedFile, type: :model do
  describe "валидации" do
    it { is_expected.to validate_inclusion_of(:file_type).in_array(%w[log screenshot config metrics_import other]) }

    it "создаётся с валидным файлом" do
      expect(build(:uploaded_file)).to be_valid
    end

    it "отклоняет файл больше 50MB" do
      uploaded = build(:uploaded_file)
      allow(uploaded.file).to receive(:byte_size).and_return(51.megabytes)
      expect(uploaded).not_to be_valid
      expect(uploaded.errors[:file]).to be_present
    end

    it "отклоняет недопустимый content_type" do
      uploaded = build(:uploaded_file)
      uploaded.file.detach
      uploaded.file.attach(io: StringIO.new("MZ..."), filename: "virus.exe",
                           content_type: "application/x-msdownload")
      expect(uploaded).not_to be_valid
      expect(uploaded.errors[:file]).to be_present
    end
  end

  describe "имя из файла" do
    it "берёт имя из вложения, если name не задан" do
      uploaded = described_class.new(file_type: "log")
      uploaded.file.attach(io: StringIO.new("data"), filename: "server.log", content_type: "text/plain")
      uploaded.valid?
      expect(uploaded.name).to eq("server.log")
    end

    it "не перезаписывает заданное имя" do
      expect(create(:uploaded_file, name: "своё.log").name).to eq("своё.log")
    end
  end

  describe "полиморфная связь" do
    it "может принадлежать алерту" do
      alert = create(:alert)
      uploaded = create(:uploaded_file, uploadable: alert)
      expect(uploaded.uploadable).to eq(alert)
      expect(alert.uploaded_files).to contain_exactly(uploaded)
    end

    it ".orphaned возвращает файлы без владельца" do
      orphan = create(:uploaded_file)
      create(:uploaded_file, uploadable: create(:alert))
      expect(described_class.orphaned).to contain_exactly(orphan)
    end
  end

  describe "типы содержимого" do
    it "#image? и #text? определяются по content_type" do
      expect(create(:uploaded_file, :image)).to be_image
      expect(create(:uploaded_file)).to be_text
      expect(create(:uploaded_file)).not_to be_image
    end
  end

  describe "скоупы" do
    it ".by_type и .by_category фильтруют" do
      log = create(:uploaded_file, file_type: "log", category: "prod")
      create(:uploaded_file, file_type: "config", category: "stage")

      expect(described_class.by_type("log")).to contain_exactly(log)
      expect(described_class.by_category("prod")).to contain_exactly(log)
      expect(described_class.by_type(nil).count).to eq(2)
    end
  end
end
