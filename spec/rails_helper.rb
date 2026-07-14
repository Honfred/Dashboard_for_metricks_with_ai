# SimpleCov должен стартовать до загрузки кода приложения
require "simplecov"
SimpleCov.start "rails" do
  add_group "Services", "app/services"
  add_group "Lib", "app/lib"
  # Метрика для badge берётся из .last_run.json
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

# Support-файлы: webmock, capybara/cuprite, factory_bot, shoulda-matchers
Rails.root.glob("spec/support/**/*.rb").sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]

  # Каждый пример в транзакции с откатом
  config.use_transactional_fixtures = true

  # Тип спека по расположению файла: spec/models -> type: :model и т.д.
  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!

  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper

  # ActiveStorage в тестах пишет в tmp/storage — подчищаем после прогона,
  # сохраняя отслеживаемый git'ом tmp/storage/.keep
  config.after(:suite) do
    storage_root = Rails.root.join("tmp/storage")
    next unless storage_root.exist?

    storage_root.children.each do |entry|
      FileUtils.rm_rf(entry) unless entry.basename.to_s == ".keep"
    end
  end
end
