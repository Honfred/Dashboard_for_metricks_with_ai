class AiAnalysis < ApplicationRecord
  belongs_to :metric

  validates :analysis_type, presence: true

  enum analysis_type: {
    anomaly_detection: 0,
    trend_prediction: 1,
    performance_insight: 2
  }

  def self.fetch_latest_analysis(metric_id, analysis_type = "anomaly_detection")
    AiService.new.fetch_analysis(metric_id, analysis_type)
  end
end
