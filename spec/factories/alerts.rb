FactoryBot.define do
  factory :alert do
    service { "web:3000" }
    sequence(:metric) { |n| "http_request_duration_seconds_#{n}" }
    value { 1.5 }
    threshold { 1.0 }
    status { "triggered" }
    severity { "warning" }
    message { "Метрика превысила пороговое значение" }
    triggered_at { Time.current }

    trait :resolved do
      status { "resolved" }
      resolved_at { Time.current }
    end

    trait :acknowledged do
      status { "acknowledged" }
    end

    trait :critical do
      severity { "critical" }
    end
  end
end
