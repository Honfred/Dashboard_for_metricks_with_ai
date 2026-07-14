require "rails_helper"

RSpec.describe "Uploads", type: :request do
  describe "GET /uploads" do
    it "отдаёт список файлов с фильтром по типу" do
      create(:uploaded_file, file_type: "log", name: "server.log")
      create(:uploaded_file, file_type: "config", name: "nginx.conf")

      get uploads_path, params: { file_type: "log" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("server.log")
      expect(response.body).not_to include("nginx.conf")
    end
  end

  describe "POST /uploads" do
    it "загружает файл и редиректит на него" do
      expect {
        post uploads_path, params: {
          uploaded_file: {
            file: fixture_file_upload("app.log", "text/plain"),
            file_type: "log",
            category: "prod"
          }
        }
      }.to change(UploadedFile, :count).by(1)

      uploaded = UploadedFile.last
      expect(response).to redirect_to(upload_path(uploaded, locale: I18n.default_locale))
      expect(uploaded.name).to eq("app.log")
      expect(uploaded.file).to be_attached
    end

    it "возвращает 422 в JSON при недопустимом типе файла" do
      post uploads_path, params: {
        uploaded_file: {
          file: fixture_file_upload("app.log", "text/plain"),
          file_type: "bogus"
        }
      }, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end
  end

  describe "GET /uploads/:id" do
    it "отдаёт JSON с метаданными файла" do
      uploaded = create(:uploaded_file)

      get upload_path(uploaded, format: :json)

      body = JSON.parse(response.body)
      expect(body["id"]).to eq(uploaded.id)
      expect(body["download_url"]).to be_present
      expect(body["file_size"]).to be_present
    end
  end

  describe "GET /uploads/:id/download и /preview" do
    it "скачивание отдаёт attachment" do
      uploaded = create(:uploaded_file)

      get download_upload_path(uploaded)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "preview отдаёт inline" do
      uploaded = create(:uploaded_file)

      get preview_upload_path(uploaded)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Disposition"]).to include("inline")
    end
  end

  describe "POST /uploads/bulk" do
    it "грузит несколько файлов разом" do
      post bulk_uploads_path, params: {
        files: [
          fixture_file_upload("app.log", "text/plain"),
          fixture_file_upload("data.csv", "text/csv")
        ],
        file_type: "log"
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["success"].size).to eq(2)
      expect(body["errors"]).to be_empty
    end

    it "возвращает 400 без файлов" do
      post bulk_uploads_path, params: {}
      expect(response).to have_http_status(:bad_request)
    end

    it "возвращает 207 при частичном успехе" do
      post bulk_uploads_path, params: {
        files: [ fixture_file_upload("app.log", "text/plain") ],
        file_type: "bogus"
      }

      expect(response).to have_http_status(:multi_status)
      body = JSON.parse(response.body)
      expect(body["errors"]).to be_present
    end
  end

  describe "DELETE /uploads/:id" do
    it "удаляет файл" do
      uploaded = create(:uploaded_file)
      expect { delete upload_path(uploaded) }.to change(UploadedFile, :count).by(-1)
    end
  end
end
