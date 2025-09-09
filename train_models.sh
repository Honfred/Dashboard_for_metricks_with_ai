#!/bin/bash

# Скрипт для запуска обучения моделей машинного обучения через Docker

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
  echo "  -m, --metric МЕТРИКА    Метрика для обучения (cpu_usage, memory_usage_bytes, http_request_duration_seconds)"
  echo "  -t, --type ТИП          Тип модели (anomaly, trend, performance)"
  echo "  -h, --help              Показать эту справку"
  echo ""
  echo "Примеры:"
  echo "  $0 -m cpu_usage -t anomaly           # Обучение модели аномалий для CPU"
  echo "  $0 -m memory_usage_bytes -t trend    # Обучение модели трендов для памяти"
  echo "  $0 -m http_request_duration_seconds -t performance  # Обучение модели производительности для времени запросов"
}

# Разбор аргументов командной строки
METRIC=""
MODEL_TYPE=""

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -m|--metric)
      METRIC="$2"
      shift
      shift
      ;;
    -t|--type)
      MODEL_TYPE="$2"
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
if [ -z "$METRIC" ] || [ -z "$MODEL_TYPE" ]; then
  echo "Ошибка: не указана метрика или тип модели"
  show_help
  exit 1
fi

# Запуск скрипта обучения модели в контейнере web
echo "Запуск обучения модели $MODEL_TYPE для метрики $METRIC..."
docker exec dashboard_web ruby scripts/train_models_api.rb -m "$METRIC" -t "$MODEL_TYPE" -u http://ml-service:5000

echo "Обучение завершено!"