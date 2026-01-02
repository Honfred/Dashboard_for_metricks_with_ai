class Metric < ApplicationRecord
  has_many :ai_analyses, dependent: :destroy

  validates :name, presence: true
  validates :metric_type, presence: true

  enum :metric_type, {
    counter: 0,
    gauge: 1,
    histogram: 2,
    summary: 3
  }

  def self.fetch_from_prometheus(service_name, time_range = "1h")
    PrometheusService.new.fetch_metrics(service_name, time_range)
  end
end
