require "rails_helper"

RSpec.describe "MlModels", type: :request do
  describe "GET /ml_models" do
    it "отдаёт список версий моделей" do
      create(:ml_model_version, :completed)
      create(:ml_model_version, :deployed, model_type: "trend")

      get ml_models_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /ml_models/:id" do
    it "отдаёт JSON с данными модели" do
      model = create(:ml_model_version, :completed)

      get ml_model_path(model, format: :json)

      body = JSON.parse(response.body)
      expect(body["id"]).to eq(model.id)
      expect(body["accuracy"]).to eq(0.95)
      expect(body["status"]).to eq("completed")
    end
  end

  describe "POST /ml_models/train" do
    it "создаёт версию и ставит джобу обучения" do
      expect {
        post train_ml_models_path, params: { model_type: "anomaly" }, as: :json
      }.to change(MlModelVersion, :count).by(1)
        .and have_enqueued_job(TrainAnomalyModelJob)

      expect(response).to have_http_status(:created)
      expect(MlModelVersion.last.status).to eq("training")
    end

    it "для типа trend ставит TrainTrendModelJob" do
      expect {
        post train_ml_models_path, params: { model_type: "trend" }, as: :json
      }.to have_enqueued_job(TrainTrendModelJob)
    end

    it "возвращает 400 при неизвестном типе" do
      post train_ml_models_path, params: { model_type: "bogus" }, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /ml_models/:id/deploy" do
    it "деплоит завершённую модель и деактивирует прежнюю" do
      old_active = create(:ml_model_version, :deployed)
      candidate  = create(:ml_model_version, :completed)

      post deploy_ml_model_path(candidate)

      expect(response).to redirect_to(ml_models_path(locale: I18n.default_locale))
      expect(candidate.reload.is_active).to be(true)
      expect(old_active.reload.is_active).to be(false)
    end

    it "отказывает незавершённой модели" do
      model = create(:ml_model_version) # training

      post deploy_ml_model_path(model)

      expect(model.reload.is_active).to be(false)
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /ml_models/:id" do
    it "удаляет неактивную модель" do
      model = create(:ml_model_version, :completed)
      expect { delete ml_model_path(model) }.to change(MlModelVersion, :count).by(-1)
    end

    it "не позволяет удалить активную модель" do
      model = create(:ml_model_version, :deployed)

      expect { delete ml_model_path(model) }.not_to change(MlModelVersion, :count)
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /ml_models/:id/download" do
    it "редиректит, если файл модели не приложен" do
      model = create(:ml_model_version, :completed)

      get download_ml_model_path(model)

      expect(response).to redirect_to(ml_models_path(locale: I18n.default_locale))
    end

    it "отдаёт файл модели" do
      model = create(:ml_model_version, :completed)
      model.model_file.attach(io: StringIO.new("binary-model"), filename: "model.pkl",
                              content_type: "application/octet-stream")

      get download_ml_model_path(model)

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("binary-model")
    end
  end
end
