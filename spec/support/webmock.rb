require "webmock/rspec"

# Внешние HTTP-запросы запрещены: Prometheus и ML-сервис стабятся явно.
# localhost разрешён для Capybara-сервера и CDP-соединения cuprite с chromium.
WebMock.disable_net_connect!(allow_localhost: true)
