require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get signup_url
    assert_response :success
  end

  test "should create user with valid params" do
    assert_difference("User.count") do
      post signup_url, params: {
        user: {
          email: "newuser@example.com",
          username: "newuser",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
    assert_not_nil session[:user_id]
    assert_equal "Account created successfully!", flash[:notice]
  end

  test "should not create user with invalid params" do
    assert_no_difference("User.count") do
      post signup_url, params: {
        user: {
          email: "invalid",
          username: "ab",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
