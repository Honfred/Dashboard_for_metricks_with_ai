require "rails_helper"

RSpec.describe "Смена локали", type: :request do
  it "сохраняет допустимую локаль в сессии и редиректит" do
    get set_locale_path(locale: "en")
    expect(response).to have_http_status(:redirect)

    stub_prometheus_query
    stub_prometheus_meta
    get root_path
    expect(response.body).to include('lang="en"')
  end

  it "игнорирует недопустимую локаль" do
    get set_locale_path(locale: "xx")
    expect(response).to have_http_status(:redirect)

    stub_prometheus_query
    stub_prometheus_meta
    get root_path
    expect(response.body).to include(%(lang="#{I18n.default_locale}"))
  end

  it "убирает параметр locale из referer при редиректе" do
    get set_locale_path(locale: "en"), headers: { "HTTP_REFERER" => "http://www.example.com/alerts?locale=ru&page=2" }
    expect(response).to redirect_to("http://www.example.com/alerts?page=2")
  end
end
