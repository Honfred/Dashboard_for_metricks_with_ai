require "capybara/rspec"
require "capybara/cuprite"

# В Alpine-контейнере chromium лежит в /usr/bin/chromium-browser,
# в CI (ubuntu) ferrum найдёт chrome сам; можно переопределить через CHROME_PATH
CUPRITE_BROWSER_PATH = ENV["CHROME_PATH"].presence ||
                       [ "/usr/bin/chromium-browser", "/usr/bin/chromium" ].find { |p| File.exist?(p) }

# ВАЖНО: Rails 7.1+ сам регистрирует драйвер :cuprite внутри driven_by,
# затирая Capybara.register_driver — поэтому опции передаются через driven_by.
# Rails мутирует хэш опций, поэтому каждый раз отдаём свежую копию
def cuprite_options
  {
    browser_path: CUPRITE_BROWSER_PATH,
    browser_options: {
      "no-sandbox" => nil, # chromium под root не стартует без этого флага
      "disable-gpu" => nil,
      "disable-dev-shm-usage" => nil
    },
    process_timeout: 30,
    timeout: 30,
    headless: true
  }
end

Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  # Без js достаточно rack_test — быстрее и не требует браузера
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :cuprite, screen_size: [ 1400, 1400 ], options: cuprite_options
  end
end
