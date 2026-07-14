# Dashboard для Metricks с AI-анализом

[![CI](https://github.com/Honfred/Dashboard_for_metricks_with_ai/actions/workflows/ci.yml/badge.svg)](https://github.com/Honfred/Dashboard_for_metricks_with_ai/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https%3A%2F%2Fgist.githubusercontent.com%2FHonfred%2FCOVERAGE_GIST_ID%2Fraw%2Fdashboard-coverage.json)](https://github.com/Honfred/Dashboard_for_metricks_with_ai/actions/workflows/ci.yml)

Интерактивный дашборд для визуализации метрик производительности систем с возможностями искусственного интеллекта для анализа и прогнозирования.

## О проекте

Возможности:
- Дашборд с настраиваемыми панелями: время отклика, пропускная способность, уровень ошибок, CPU/память (перетаскивание панелей, выбор временного диапазона и интервала автообновления)
- Система оповещений: статусы triggered/acknowledged/resolved, фильтры по важности и сервису
- AI-анализ метрик через ML-сервис: поиск аномалий, прогноз трендов, анализ производительности
- Управление версиями ML-моделей: обучение, деплой, скачивание
- Отчёты в PDF/CSV/JSON с фоновой генерацией и сроком жизни
- Загрузка файлов (логи, скриншоты, конфиги) с привязкой к сущностям
- Интерфейс на русском и английском

Стек: Ruby on Rails 7.2 (Ruby 3.1), Turbo + Stimulus (importmap, без сборщика), Chart.js, PostgreSQL, Redis + Sidekiq (фоновые задачи), MinIO (S3-совместимое хранилище файлов), Prometheus (сбор метрик), ML-сервис на Python (каталог `modules/AI_api`).

## Требования

- Docker и Docker Compose
- Git

## Быстрый старт

### Установка и запуск

1. Клонируйте репозиторий:
```bash
git clone https://github.com/Honfred/Dashboard_for_metricks_with_ai.git
cd Dashboard_for_metricks_with_ai
```

2. Соберите и запустите все сервисы:
```bash
make build
make start
```

3. Создайте базу данных и заполните её демо-данными:
```bash
make generate-test-data
```

4. Откройте дашборд в браузере: http://localhost:3000

### Сервисы docker-compose

| Сервис | Адрес | Назначение |
|---|---|---|
| web | http://localhost:3000 | Rails-приложение |
| sidekiq | — | фоновые задачи (генерация отчётов, обучение моделей, проверка алертов) |
| prometheus | http://localhost:9090 | сбор и хранение метрик |
| ml-service | http://localhost:5000 | Python-сервис AI-анализа |
| minio | http://localhost:9001 | консоль S3-хранилища (файлы, отчёты, модели) |
| postgres, redis | — | база данных и кэш/очереди |
| pushgateway, node/postgres/redis-exporter | :9091, :9100, :9187, :9121 | экспортеры метрик для Prometheus |

### Основные команды

- `make start` / `make stop` / `make restart` — запуск, остановка, перезапуск всех сервисов
- `make build` / `make rebuild` — сборка контейнеров / полная пересборка
- `make restart-web`, `make restart-sidekiq` — перезапуск отдельного сервиса
- `make setup-db` — создание БД и миграции
- `make generate-test-data` — демо-данные (метрики, алерты, анализы)

### Переменные окружения

- `DASHBOARD_DEMO_DATA` — `true` включает демо-данные на дашборде при отсутствии реальных метрик (по умолчанию `false`)
- `PROMETHEUS_URL`, `ML_SERVICE_URL`, `AI_SERVICE_URL` — адреса внешних сервисов
- `REDIS_URL`, `REDIS_CACHE_URL` — очереди Sidekiq (db 0) и кэш Rails (db 1)
- `MINIO_*`, `STORAGE_SERVICE` — настройки S3-хранилища

## Тестирование

Тесты написаны на RSpec (модели, request-спеки, E2E на Capybara + cuprite) и запускаются в Docker:

```bash
# Подготовка тестовой базы (один раз)
docker compose exec -T web ash -c "RAILS_ENV=test bin/rails db:prepare"

# Весь сьют
docker compose exec -T web ash -c "RAILS_ENV=test PROMETHEUS_URL=http://prometheus.test:9090 ML_SERVICE_URL=http://ml.test:5000 AI_SERVICE_URL=http://ml.test:5000 bundle exec rspec"

# Отдельный файл
docker compose exec -T web ash -c "RAILS_ENV=test bundle exec rspec spec/models/alert_spec.rb"
```

Внешние сервисы (Prometheus, ML) в тестах замоканы через WebMock — фиктивные хосты
`prometheus.test`/`ml.test` гарантируют, что ни один запрос не уйдёт наружу.
E2E-тесты с JS (`js: true`) используют chromium из Docker-образа.

Отчёт о покрытии (simplecov) пишется в `coverage/index.html` после каждого прогона.

### Badge покрытия

CI обновляет badge через gist. Для включения нужно один раз:
1. Создать [gist](https://gist.github.com) с файлом `dashboard-coverage.json` (содержимое любое).
2. Создать token с правом `gist` и добавить его в секреты репозитория как `GIST_SECRET`.
3. Добавить repo-переменную `COVERAGE_GIST_ID` со значением id созданного gist.
4. Заменить `COVERAGE_GIST_ID` в URL badge выше на реальный id gist.

## Структура проекта

- `app/` — основной код приложения
  - `controllers/` — контроллеры (dashboard, metrics, alerts, ai_analyses, reports, uploads, ml_models)
  - `models/` — модели (Metric, Alert, AiAnalysis, MlModelVersion, Report, UploadedFile, DashboardSetting)
  - `services/` — интеграции: PrometheusService, MlService, AiService, AlertsService, ReportExportService
  - `jobs/` — фоновые задачи Sidekiq (генерация отчётов, обучение моделей, AI-анализ, проверка метрик)
  - `views/`, `javascript/` — представления и фронтенд (модули дашборда, Stimulus-контроллеры)
- `spec/` — тесты RSpec (models, requests, system) с фабриками и стабами внешних сервисов
- `modules/AI_api/` — Python ML-сервис (Flask, обучение и применение моделей)
- `config/` — конфигурация Rails; `prometheus.yml`, `alerts.yml` — конфигурация Prometheus
- `db/` — миграции и схема базы данных
- `.github/workflows/` — CI (rubocop, brakeman, importmap audit, rspec) и релизы Docker-образа

## Страницы приложения

- `/` — список метрик и источников данных Prometheus
- `/dashboard` — основной дашборд с панелями
- `/dashboard/ai_overview` — сводка AI-анализов
- `/alerts` — оповещения
- `/reports` — отчёты
- `/uploads` — загруженные файлы
- `/ml_models` — версии ML-моделей
- `/prometheus/status` — статус источников данных

## Работа с дашбордом

### Режим редактирования
Для перемещения панелей используйте режим редактирования, который можно включить кнопкой "Режим редактирования" в верхней части интерфейса.

### Настройка обновления данных
Выберите интервал автоматического обновления данных из выпадающего списка в верхней части страницы.

### Временной диапазон
Выберите временной диапазон для отображения метрик (последние 15 минут, час, день и т.д.).
