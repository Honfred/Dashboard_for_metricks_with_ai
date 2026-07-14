# frozen_string_literal: true

# Конфигурация локализации приложения
# Application localization configuration

Rails.application.config.i18n.available_locales = [ :ru, :en ]
Rails.application.config.i18n.default_locale = :ru

# Включаем fallback на английский язык, если перевод не найден
Rails.application.config.i18n.fallbacks = [ :en ]
