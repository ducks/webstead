require "test_helper"

class WebsteadsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_webstead_url
    assert_response :success
  end

  test "should create webstead with valid data" do
    assert_difference([ "User.count", "Webstead.count" ], 1) do
      post websteads_url, params: {
        user: {
          email: "test@example.com",
          username: "testuser",
          password: "password123",
          password_confirmation: "password123"
        },
        webstead: {
          subdomain: "mywebstead"
        }
      }
    end

    assert_redirected_to provisioning_webstead_path(Webstead.last)
    assert_not_nil session[:user_id]
  end

  test "should not create webstead with invalid subdomain" do
    assert_no_difference([ "User.count", "Webstead.count" ]) do
      post websteads_url, params: {
        user: {
          email: "test@example.com",
          username: "testuser",
          password: "password123",
          password_confirmation: "password123"
        },
        webstead: {
          subdomain: "ab"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should check subdomain availability" do
    get check_availability_websteads_url, params: { subdomain: "available" }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["available"]
  end

  test "should return unavailable for taken subdomain" do
    webstead = Webstead.create!(
      subdomain: "taken",
      user: User.create!(email: "user@example.com", username: "user", password: "password123")
    )

    get check_availability_websteads_url, params: { subdomain: "taken" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["available"]
  end

  test "should return unavailable for reserved subdomain" do
    get check_availability_websteads_url, params: { subdomain: "admin" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["available"]
    assert_includes json["message"], "reserved"
  end
end
