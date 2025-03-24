require "test_helper"

class AlertsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get alerts_index_url
    assert_response :success
  end

  test "should get show" do
    get alerts_show_url
    assert_response :success
  end

  test "should get update" do
    get alerts_update_url
    assert_response :success
  end
end
