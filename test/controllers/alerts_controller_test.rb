require "test_helper"

class AlertsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alert = alerts(:one)
  end

  test "should get index" do
    get alerts_url
    assert_response :success
  end

  test "should get show" do
    get alert_url(@alert)
    assert_response :success
  end

  test "should update alert" do
    patch alert_url(@alert), params: { alert: { status: "resolved" } }
    assert_redirected_to alert_url(@alert, locale: I18n.default_locale)
  end

  test "should get active alerts as json" do
    get active_alerts_url(format: :json)
    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body
    assert body.all? { |a| a["status"] == "triggered" }
  end

  test "should create alert from json payload" do
    assert_difference("Alert.count") do
      post alerts_url, params: {
        service: "api-gateway",
        metric: "response_time",
        value: 0.9,
        threshold: 0.5,
        severity: "critical"
      }, as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "api-gateway", body.dig("alert", "service")
  end

  test "create updates existing active alert instead of duplicating" do
    assert_no_difference("Alert.count") do
      post alerts_url, params: {
        service: @alert.service,
        metric: @alert.metric,
        value: 2.5,
        threshold: 1.0,
        severity: "critical"
      }, as: :json
    end
    assert_response :created
    assert_equal 2.5, @alert.reload.value
  end
end
