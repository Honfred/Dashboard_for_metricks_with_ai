FactoryBot.define do
  factory :report do
    sequence(:name) { |n| "Отчёт #{n}" }
    report_type { "metrics" }
    add_attribute(:format) { "csv" }
    status { "pending" }
    parameters { {} }
    metadata { {} }

    trait :pdf do
      add_attribute(:format) { "pdf" }
    end

    trait :completed do
      status { "completed" }
      generated_at { Time.current }

      after(:create) do |report|
        report.file.attach(
          io: StringIO.new("id,name\n1,test\n"),
          filename: "report.csv",
          content_type: "text/csv"
        )
      end
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
