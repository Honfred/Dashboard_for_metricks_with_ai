require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.options[:concurrency] = 2
  
  # Настройка планировщика задач
  config.on(:startup) do
    Sidekiq.schedule = {
      'model_training_weekly' => {
        'every' => ['1w', first_in: '1h'],
        'class' => 'ScheduleModelTrainingJob',
        'queue' => 'default',
        'enabled' => true
      }
    }
    Sidekiq::Scheduler.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/1' }
end