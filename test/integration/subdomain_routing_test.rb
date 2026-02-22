require "test_helper"

class SubdomainRoutingTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "alice@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @webstead = Webstead.create!(
      user: @user,
      subdomain: "alice"
    )
  end

  test "valid subdomain resolves to correct webstead" do
    get posts_url, headers: { "Host": "alice.webstead.test" }
    assert_response :success
    assert_equal @webstead, Current.webstead
  end

  test "invalid subdomain returns 404" do
    get posts_url, headers: { "Host": "nonexistent.webstead.test" }
    assert_response :not_found
    assert_match /Webstead Not Found/, response.body
  end

  test "reserved subdomain www is excluded" do
    get root_url, headers: { "Host": "www.webstead.test" }
    assert_response :success
    assert_nil Current.webstead
  end

  test "reserved subdomain api is excluded" do
    get root_url, headers: { "Host": "api.webstead.test" }
    assert_response :success
    assert_nil Current.webstead
  end

  test "reserved subdomain admin is excluded" do
    get root_url, headers: { "Host": "admin.webstead.test" }
    assert_response :success
    assert_nil Current.webstead
  end

  test "root domain without subdomain shows landing page" do
    get root_url, headers: { "Host": "webstead.test" }
    assert_response :success
    assert_nil Current.webstead
  end

  test "subdomain with custom domain resolves correctly" do
    @webstead.update!(custom_domain: "alice.example.com")
    get posts_url, headers: { "Host": "alice.webstead.test" }
    assert_response :success
    assert_equal @webstead, Current.webstead
  end
end
