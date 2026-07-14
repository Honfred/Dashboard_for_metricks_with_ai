FactoryBot.define do
  factory :ai_analysis do
    metric
    analysis_type { :anomaly_detection }
    status { "pending" }

    trait :completed do
      status { "completed" }
      completed_at { Time.current }
      report do
        {
          "insights" => [
            { "severity" => "high", "text" => "Обнаружена аномалия" },
            { "severity" => "low", "text" => "Незначительное отклонение" }
          ],
          "events" => [
            { "timestamp" => 1_700_000_000, "value" => 42.0, "deviation" => 3.2 }
          ]
        }
      end
    end

    trait :failed do
      status { "failed" }
    end

    trait :trend do
      analysis_type { :trend_prediction }
    end

    trait :performance do
      analysis_type { :performance_insight }
    end
  end
end
