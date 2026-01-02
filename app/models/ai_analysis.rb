class AiAnalysis < ApplicationRecord
  belongs_to :metric

  validates :analysis_type, presence: true
  
  # Enum для типов анализа
  enum :analysis_type, {
    anomaly_detection: 0,
    trend_prediction: 1,
    performance_insight: 2
  }
  
  # Enum для статусов анализа
  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, default: "pending"

  # Методы для работы с результатами анализа
  def completed?
    status == 'completed' && completed_at.present?
  end
  
  def failed?
    status == 'failed'
  end

  def processing_time
    return nil unless completed_at.present? && created_at.present?
    (completed_at - created_at).to_i
  end
  
  def insights_count
    return 0 unless report.present? && report['insights'].present?
    report['insights'].size
  end

  def high_severity_insights_count
    return 0 unless report.present? && report['insights'].present?
    report['insights'].count { |i| i['severity'] == 'high' }
  end

  # Получение данных анализа
  def self.fetch_latest_analysis(metric_id, analysis_type = "anomaly_detection")
    AiService.new.fetch_analysis(metric_id, analysis_type)
  end
end
