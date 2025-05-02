#!/bin/bash

# Скрипт для проверки обученных моделей машинного обучения через Docker

# Проверка, что Docker запущен и контейнеры работают
if ! docker ps &>/dev/null; then
  echo "Ошибка: Docker не запущен или требуются права администратора"
  exit 1
fi

# Проверка, что контейнер с ml-service запущен
if ! docker ps | grep -q ml-service; then
  echo "Ошибка: Контейнер ml-service не запущен"
  echo "Запустите сначала docker-compose up -d"
  exit 1
fi

# Функция для вывода справки
show_help() {
  echo "Использование: $0 [опции]"
  echo ""
  echo "Опции:"
  echo "  -m, --metric МЕТРИКА    Метрика для проверки (cpu_usage, memory_usage_bytes, http_request_duration_seconds)"
  echo "  -a, --action ДЕЙСТВИЕ   Действие (anomalies, trend, performance)"
  echo "  -h, --help              Показать эту справку"
  echo ""
  echo "Примеры:"
  echo "  $0 -m cpu_usage -a anomalies           # Проверка аномалий для CPU"
  echo "  $0 -m memory_usage_bytes -a trend      # Проверка трендов для памяти"
  echo "  $0 -m http_request_duration_seconds -a performance  # Проверка производительности для времени запросов"
}

# Разбор аргументов командной строки
METRIC=""
ACTION=""

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -m|--metric)
      METRIC="$2"
      shift
      shift
      ;;
    -a|--action)
      ACTION="$2"
      shift
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Неизвестная опция: $1"
      show_help
      exit 1
      ;;
  esac
done

# Проверка наличия обязательных аргументов
if [ -z "$METRIC" ] || [ -z "$ACTION" ]; then
  echo "Ошибка: не указана метрика или действие"
  show_help
  exit 1
fi

# Запуск скрипта проверки модели в контейнере web
echo "Запуск проверки '$ACTION' для метрики $METRIC..."
docker exec dashboard_web ruby scripts/check_models.rb -m "$METRIC" -a "$ACTION" -u http://ml-service:5000

echo "Проверка завершена!"