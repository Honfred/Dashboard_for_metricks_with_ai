source "https://rubygems.org"

gem "rails", "~> 7.2.2", ">= 7.2.2.1"

gem "sprockets-rails"

gem "prometheus-client"
gem "sidekiq"
gem "sidekiq-scheduler"
gem "redis"
gem "chartkick"
gem "groupdate"
gem "pg", "~> 1.5", ">= 1.5.6"
gem "httparty"
gem "kaminari"

# ActiveStorage S3 support
gem "aws-sdk-s3", require: false

# PDF generation
gem "prawn"
gem "prawn-table"

# CSV export already in stdlib

gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails"
end

group :test do
  gem "capybara"
  gem "cuprite"
  gem "webmock"
  gem "shoulda-matchers"
  gem "simplecov", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end
