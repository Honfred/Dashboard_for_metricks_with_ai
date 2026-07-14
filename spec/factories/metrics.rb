FactoryBot.define do
  factory :metric do
    sequence(:name) { |n| "test_metric_#{n}" }
    description { "Тестовая метрика" }
    metric_type { :gauge }

    trait :counter do
      metric_type { :counter }
    end

    trait :histogram do
      metric_type { :histogram }
    end
  end
end
