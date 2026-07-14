FactoryBot.define do
  factory :ml_model_version do
    model_type { "anomaly" }
    status { "training" }
    metadata { {} }
    metrics { {} }

    trait :completed do
      status { "completed" }
      trained_at { Time.current }
      metrics { { "accuracy" => 0.95, "f1_score" => 0.9 } }
    end

    trait :deployed do
      status { "deployed" }
      is_active { true }
      trained_at { 1.hour.ago }
      deployed_at { Time.current }
    end
  end
end
