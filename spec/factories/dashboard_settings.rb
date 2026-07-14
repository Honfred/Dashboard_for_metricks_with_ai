FactoryBot.define do
  factory :dashboard_setting do
    name { "default" }
    settings { DashboardSetting.default_settings }
  end
end
