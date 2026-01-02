# frozen_string_literal: true

namespace :ml_models do
  desc "Импорт существующих ML моделей из modules/AI_api/models/"
  task import: :environment do
    models_dir = Rails.root.join('modules', 'AI_api', 'models')
    
    unless Dir.exist?(models_dir)
      puts "Директория моделей не найдена: #{models_dir}"
      exit 1
    end

    imported = 0
    skipped = 0

    Dir.glob(models_dir.join('*.joblib')).each do |file_path|
      filename = File.basename(file_path, '.joblib')
      
      # Парсим имя файла: metric_name_model_type.joblib
      # Например: http_requests_total_anomaly.joblib
      parts = filename.split('_')
      model_type = parts.pop  # anomaly, trend, performance
      metric_name = parts.join('_')

      next unless %w[anomaly trend performance].include?(model_type)

      # Проверяем, нет ли уже такой модели
      existing = MlModelVersion.find_by(
        model_type: model_type,
        metadata: { 'metric_name' => metric_name }.to_json
      )

      if existing
        puts "Пропуск: #{filename} (уже существует)"
        skipped += 1
        next
      end

      # Создаём запись о модели
      model_version = MlModelVersion.new(
        model_type: model_type,
        status: 'completed',
        trained_at: File.mtime(file_path),
        metadata: {
          metric_name: metric_name,
          source: 'import',
          original_path: file_path,
          imported_at: Time.current.iso8601
        }
      )

      # Прикрепляем файл модели
      model_version.model_file.attach(
        io: File.open(file_path),
        filename: File.basename(file_path),
        content_type: 'application/octet-stream'
      )

      if model_version.save
        puts "Импортировано: #{filename} -> #{model_version.model_type} v#{model_version.version}"
        imported += 1
      else
        puts "Ошибка импорта #{filename}: #{model_version.errors.full_messages.join(', ')}"
      end
    end

    puts "\n=== Итоги импорта ==="
    puts "Импортировано: #{imported}"
    puts "Пропущено: #{skipped}"
    puts "Всего моделей в базе: #{MlModelVersion.count}"
  end

  desc "Активировать лучшие модели каждого типа"
  task activate_best: :environment do
    %w[anomaly performance trend].each do |model_type|
      latest = MlModelVersion.by_type(model_type).completed.recent.first
      if latest && !latest.is_active?
        latest.deploy!
        puts "Активирована: #{model_type} v#{latest.version}"
      elsif latest&.is_active?
        puts "Уже активна: #{model_type} v#{latest.version}"
      else
        puts "Нет моделей типа: #{model_type}"
      end
    end
  end

  desc "Показать статус всех моделей"
  task status: :environment do
    puts "\n=== Статус ML моделей ===\n"
    
    %w[anomaly performance trend].each do |model_type|
      models = MlModelVersion.by_type(model_type).recent
      active = models.find(&:is_active?)
      
      puts "\n#{model_type.upcase}:"
      puts "  Всего версий: #{models.count}"
      puts "  Активная: #{active ? "v#{active.version}" : 'нет'}"
      
      models.limit(3).each do |m|
        status_icon = m.is_active? ? '✓' : ' '
        puts "  [#{status_icon}] v#{m.version} - #{m.status} (#{m.trained_at&.strftime('%Y-%m-%d %H:%M') || 'N/A'})"
      end
    end
  end
end
