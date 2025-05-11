Rails.application.routes.draw do
  get "alerts/index"
  get "alerts/show"
  get "alerts/update"
  # Корневой маршрут
  root 'metrics#index'

  # Маршруты для метрик
  resources :metrics do
    resources :ai_analyses, only: [:index, :new, :create, :show]
  end
  
  # Переименовываем ресурс метрик для панели управления
  scope '/dashboard' do
    resources :metrics, as: 'dashboard_metrics', path: 'metrics'
  end
  
  # Добавляем маршрут для проверки статуса источников данных Prometheus
  get 'prometheus/status', to: 'prometheus#status'
  
  # Добавляем маршрут для пользовательских метрик для Prometheus
  get 'custom-metrics', to: 'metrics#custom_metrics'
  
  # Маршруты для анализа метрик с помощью AI без привязки к метрике
  resources :ai_analyses, only: [:index, :show, :destroy]

  # Маршруты для оповещений
  resources :alerts, only: [:index, :show, :update] do
    member do
      post 'resolve'
      post 'acknowledge'
    end
    collection do
      get 'active'
    end
  end
  
  # Маршруты для API оповещений
  namespace :api do
    resources :alerts, only: [:index, :create] do
      collection do
        get 'active'
      end
    end
  end

  # Добавляем маршрут для проверки статуса ML-сервиса
  get 'check_ml_service', to: 'metrics#check_ml_service'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  resources :dashboard, only: [ :index ] do
    collection do
      get "metrics"
      post "save_settings"
      get "settings"  # Добавляем маршрут для получения настроек
      # Панель управления ИИ-анализом
      get "ai_overview"
    end
  end
end
