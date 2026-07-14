# frozen_string_literal: true

class UploadsController < ApplicationController
  before_action :set_uploaded_file, only: [ :show, :destroy, :download, :preview ]

  # GET /uploads
  def index
    @uploaded_files = UploadedFile.includes(file_attachment: :blob)
                                  .by_type(params[:file_type])
                                  .by_category(params[:category])
                                  .recent
                                  .page(params[:page])
                                  .per(20)
  end

  # GET /uploads/:id
  def show
    respond_to do |format|
      format.html
      format.json { render json: upload_json(@uploaded_file) }
    end
  end

  # GET /uploads/new
  def new
    @uploaded_file = UploadedFile.new
  end

  # POST /uploads
  def create
    @uploaded_file = UploadedFile.new(uploaded_file_params)

    respond_to do |format|
      if @uploaded_file.save
        format.html { redirect_to upload_path(@uploaded_file), notice: t("uploads.created") }
        format.json { render json: upload_json(@uploaded_file), status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @uploaded_file.errors }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /uploads/:id
  def destroy
    @uploaded_file.destroy

    respond_to do |format|
      format.html { redirect_to uploads_path, notice: t("uploads.deleted") }
      format.json { head :no_content }
    end
  end

  # GET /uploads/:id/download
  def download
    if @uploaded_file.file.attached?
      # Проксируем файл через контроллер, чтобы избежать проблем с внутренним URL MinIO
      send_data @uploaded_file.file.download,
                filename: @uploaded_file.file.filename.to_s,
                type: @uploaded_file.file.content_type,
                disposition: "attachment"
    else
      redirect_to uploads_path, alert: t("uploads.file_not_found")
    end
  end

  # GET /uploads/:id/preview
  def preview
    if @uploaded_file.file.attached?
      send_data @uploaded_file.file.download,
                filename: @uploaded_file.file.filename.to_s,
                type: @uploaded_file.file.content_type,
                disposition: "inline"
    else
      head :not_found
    end
  end

  # POST /uploads/bulk
  def bulk_upload
    files = Array(params[:files]).reject(&:blank?)
    if files.empty?
      render json: { error: t("uploads.no_files", default: "Файлы не переданы") }, status: :bad_request
      return
    end

    results = { success: [], errors: [] }

    files.each do |file|
      uploaded_file = UploadedFile.new(
        file: file,
        file_type: params[:file_type] || "other",
        category: params[:category]
      )

      if uploaded_file.save
        results[:success] << upload_json(uploaded_file)
      else
        results[:errors] << {
          filename: file.original_filename,
          errors: uploaded_file.errors.full_messages
        }
      end
    end

    render json: results, status: results[:errors].any? ? :multi_status : :created
  end

  private

  def set_uploaded_file
    @uploaded_file = UploadedFile.find(params[:id])
  end

  def uploaded_file_params
    params.require(:uploaded_file).permit(
      :name, :file_type, :category, :description, :file,
      :uploadable_type, :uploadable_id
    )
  end

  def upload_json(uploaded_file)
    {
      id: uploaded_file.id,
      name: uploaded_file.name,
      file_type: uploaded_file.file_type,
      category: uploaded_file.category,
      description: uploaded_file.description,
      file_url: uploaded_file.file_url,
      download_url: uploaded_file.download_url,
      file_size: uploaded_file.file_size_human,
      content_type: uploaded_file.content_type,
      created_at: uploaded_file.created_at.iso8601
    }
  end
end
