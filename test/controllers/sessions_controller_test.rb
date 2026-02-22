require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@example.com",
      username: "testuser",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should get new" do
    get login_url
    assert_response :success
  end

  test "should create session with valid credentials" do
    post login_url, params: { email: @user.email, password: "password123" }
    assert_redirected_to root_path
    assert_equal @user.id, session[:user_id]
    assert_equal "Logged in successfully.", flash[:notice]
  end

  test "should not create session with invalid credentials" do
    post login_url, params: { email: @user.email, password: "wrongpassword" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_equal "Invalid email or password.", flash[:alert]
  end

  test "should destroy session" do
    post login_url, params: { email: @user.email, password: "password123" }
    delete logout_url
    assert_redirected_to root_path
    assert_nil session[:user_id]
    assert_equal "Logged out successfully.", flash[:notice]
  end
end
