require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "save_settings persists permitted settings including nested layout" do
    post save_settings_dashboard_index_url, params: {
      settings: {
        refresh_interval: "60s",
        time_range: "3h",
        displayed_panels: [ "service-health", "error-rate" ],
        layout: { rows: [ { panels: [ "service-health" ] }, { panels: [ "error-rate" ] } ] }
      }
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "60s", body.dig("settings", "refresh_interval")

    stored = DashboardSetting.current("default").settings
    assert_equal "3h", stored["time_range"]
    assert_equal [ { "panels" => [ "service-health" ] }, { "panels" => [ "error-rate" ] } ],
                 stored.dig("layout", "rows")
  end

  test "save_settings drops keys outside the permitted list" do
    post save_settings_dashboard_index_url, params: {
      settings: {
        refresh_interval: "30s",
        malicious_key: "evil",
        layout: { rows: [ { panels: [ "throughput" ], injected: "evil" } ] }
      }
    }, as: :json

    assert_response :success
    stored = DashboardSetting.current("default").settings
    assert_not stored.key?("malicious_key")
    assert_equal [ { "panels" => [ "throughput" ] } ], stored.dig("layout", "rows")
  end
end
