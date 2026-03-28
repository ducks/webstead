require "test_helper"

class SetCurrentWebsteadTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "alice@example.com",
      username: "alice",
      password: "password123",
      password_confirmation: "password123"
    )
    @webstead = Webstead.create!(
      user: @user,
      subdomain: "alice"
    )
  end

  test "sets Current.webstead for valid subdomain" do
    get root_url, headers: { "Host" => "alice.webstead.test" }
    assert_response :success
    assert_equal @webstead, Current.webstead
  end

  test "returns 404 for unknown subdomain" do
    get root_url, headers: { "Host" => "nonexistent.webstead.test" }
    assert_response :not_found
    assert_includes response.body, "Webstead Not Found"
  end

  test "resolves webstead by custom domain" do
    @webstead.update!(custom_domain: "alice.example.com")
    get root_url, headers: { "Host" => "alice.example.com" }
    assert_response :success
    assert_equal @webstead, Current.webstead
  end

  test "skips middleware for root domain (no subdomain)" do
    get root_url, headers: { "Host" => "webstead.test" }
    assert_response :success
    assert_nil Current.webstead
  end

  test "skips middleware for reserved subdomain www" do
    get root_url, headers: { "Host" => "www.webstead.test" }
    assert_response :success
    assert_nil Current.webstead
  end

  test "skips middleware for reserved subdomain api" do
    get root_url, headers: { "Host" => "api.webstead.test" }
    assert_response :success
    assert_nil Current.webstead
  end

  test "skips middleware for reserved subdomain admin" do
    get root_url, headers: { "Host" => "admin.webstead.test" }
    assert_response :success
    assert_nil Current.webstead
  end

  test "resets Current.webstead between requests" do
    get root_url, headers: { "Host" => "alice.webstead.test" }
    assert_equal @webstead, Current.webstead

    get root_url, headers: { "Host" => "webstead.test" }
    assert_nil Current.webstead
  end
end
