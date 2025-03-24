Rails.application.config.after_initialize do
  # Запускаем задачу проверки метрик при запуске сервера в production
  # В режиме разработки задачу можно запускать вручную для отладки
  if Rails.env.production? && defined?(Rails::Server)
    Rails.logger.info "Scheduling initial CheckMetricsJob at \#{Time.current}"
    
    # Небольшая задержка для полной инициализации приложения
    CheckMetricsJob.set(wait: 1.minute).perform_later
  end
end
