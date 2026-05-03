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
end
