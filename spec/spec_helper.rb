# Общая конфигурация RSpec, не зависящая от Rails
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Позволяет запускать отдельные примеры через `fit`/`:focus`
  config.filter_run_when_matching :focus

  # Порядок выполнения случайный, чтобы ловить зависимость тестов друг от друга
  config.order = :random
  Kernel.srand config.seed
end
