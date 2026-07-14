# Как внести вклад

Спасибо за интерес к проекту! Ниже — короткая инструкция, как устроена разработка.

## Окружение

Вся разработка ведётся через Docker — локальные Ruby/PostgreSQL не нужны:

```bash
make start        # поднять все сервисы (web, postgres, redis, prometheus и т.д.)
make setup-db     # подготовить базу
make stop         # остановить
```

Приложение доступно на http://localhost:3000, Prometheus — на http://localhost:9090.

Команды внутри контейнера выполняются через `docker compose exec web …`.

## Тесты

```bash
docker compose exec web bundle exec rspec               # юнит- и request-спеки
docker compose exec web bundle exec rspec spec/system   # системные тесты (браузер)
```

Перед PR убедитесь, что тесты проходят: CI гоняет `db:test:prepare` и `bundle exec rspec`.

## Стиль кода

- Ruby: RuboCop с конфигом `rubocop-rails-omakase` — `docker compose exec web bin/rubocop`.
- Безопасность: `docker compose exec web bundle exec brakeman` не должен приносить новых предупреждений.

## Особенности проекта, о которых легко споткнуться

- **Turbo**: внешние библиотеки подключаются в `<head>`, инициализация страниц —
  по событию `turbo:load`, формы при ошибках должны отвечать статусом 422.
- **Демо-данные**: переменная окружения `DASHBOARD_DEMO_DATA` переключает дашборд
  между реальными метриками Prometheus и сгенерированными данными.

## Pull Request

1. Создайте ветку от `master` (`fix/…` или `feature/…`).
2. Делайте небольшие осмысленные коммиты.
3. Заполните шаблон PR — особенно раздел «Как проверить».
