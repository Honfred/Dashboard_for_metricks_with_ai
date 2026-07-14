require "rails_helper"

RSpec.describe "Загрузка файлов", type: :system do
  it "загружает файл через форму" do
    visit new_upload_path

    attach_file "uploaded_file[file]", Rails.root.join("spec/fixtures/files/app.log")
    select I18n.t("uploads.types.log"), from: "uploaded_file[file_type]"
    fill_in "uploaded_file[category]", with: "ml-training"

    expect {
      click_button I18n.t("uploads.upload")
    }.to change(UploadedFile, :count).by(1)

    uploaded = UploadedFile.last
    expect(uploaded.name).to eq("app.log")
    expect(uploaded.file).to be_attached
    expect(page).to have_content("app.log")
  end

  it "показывает ошибку при недопустимом типе файла" do
    visit new_upload_path

    attach_file "uploaded_file[file]", Rails.root.join("spec/fixtures/files/app.log")
    select I18n.t("uploads.types.log"), from: "uploaded_file[file_type]"

    # Подсовываем недопустимый тип через невалидный file_type в модели нельзя,
    # поэтому проверяем серверную валидацию на пустом файле: без файла форма
    # не проходит браузерный required, а с недопустимым MIME — серверную проверку.
    # Здесь загружаем файл-пустышку с расширением .exe
    exe = Rails.root.join("tmp/fake.exe")
    File.binwrite(exe, "MZ\x90\x00")
    attach_file "uploaded_file[file]", exe

    click_button I18n.t("uploads.upload")

    expect(page).to have_css(".alert-danger")
    expect(UploadedFile.count).to eq(0)
  ensure
    FileUtils.rm_f(Rails.root.join("tmp/fake.exe"))
  end

  it "пагинирует список файлов по 20" do
    create_list(:uploaded_file, 21)

    visit uploads_path

    expect(page).to have_css(".pagination")
    click_link "2"
    expect(page).to have_css("tbody tr", count: 1)
  end
end
