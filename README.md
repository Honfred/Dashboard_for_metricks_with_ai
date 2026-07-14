# Dashboard для Metricks с AI-анализом

[![CI](https://github.com/Honfred/Dashboard_for_metricks_with_ai/actions/workflows/ci.yml/badge.svg)](https://github.com/Honfred/Dashboard_for_metricks_with_ai/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https%3A%2F%2Fgist.githubusercontent.com%2FHonfred%2FCOVERAGE_GIST_ID%2Fraw%2Fdashboard-coverage.json)](https://github.com/Honfred/Dashboard_for_metricks_with_ai/actions/workflows/ci.yml)

Интерактивный дашборд для визуализации метрик производительности систем с возможностями искусственного интеллекта для анализа и прогнозирования.

## О проекте

Данный дашборд предоставляет следующие возможности:
- Визуализация метрик: время отклика, пропускная способность, уровень ошибок
- Мониторинг использования ресурсов: CPU, память, дисковое пространство
- Система оповещений о критических значениях метрик
- Настраиваемый интерфейс с возможностью перетаскивания панелей
- AI-анализ метрик для выявления аномалий и прогнозирования проблем

Проект разработан на Ruby on Rails с использованием JavaScript для интерактивных элементов. Данные визуализируются с помощью библиотеки Chart.js, а система мониторинга использует Prometheus.

## Требования

- Docker и Docker Compose
- Git

## Быстрый старт

### Установка и запуск

1. Клонируйте репозиторий:
```bash
git clone https://github.com/username/dashboard_for_metricks_with_ai.git
cd dashboard_for_metricks_with_ai
```

2. Запустите приложение с помощью Docker Compose:
```bash
make build
make start
```

3. Создайте базу данных и выполните миграции:
```bash
docker compose exec web rails db:create db:migrate
```

4. Заполните систему тестовыми данными:
```bash
make generate-test-data
```

5. Откройте дашборд в браузере:
```
http://localhost:3000
```

### Основные команды

Доступные Makefile команды:
- `make start` - запуск всех сервисов
- `make stop` - остановка всех сервисов
- `make restart` - перезапуск всех сервисов
- `make build` - сборка контейнеров
- `make rebuild` - полная пересборка проекта
- `make generate-test-data` - генерация тестовых данных для демонстрации

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

- `app/` - основной код приложения
  - `controllers/` - контроллеры Rails
  - `models/` - модели данных
  - `views/` - представления и шаблоны
  - `javascript/` - код JavaScript для интерактивных элементов
- `config/` - конфигурационные файлы
- `db/` - миграции базы данных и схема
- `docker-compose.yml` - настройки Docker Compose

## Работа с дашбордом

### Режим редактирования
Для перемещения панелей используйте режим редактирования, который можно включить кнопкой "Режим редактирования" в верхней части интерфейса.

### Настройка обновления данных
Выберите интервал автоматического обновления данных из выпадающего списка в верхней части страницы.

### Временной диапазон
Выберите временной диапазон для отображения метрик (последние 15 минут, час, день и т.д.).

## Мониторинг Prometheus

Дашборд интегрирован с Prometheus для сбора и анализа метрик. Вы можете получить доступ к интерфейсу Prometheus:

```
http://localhost:9090
```
