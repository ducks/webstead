require "test_helper"

class TenantIsolationIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user_a = User.create!(
      email: "alice@example.com",
      username: "alice",
      password: "password123",
      password_confirmation: "password123"
    )
    @webstead_a = Webstead.create!(user: @user_a, subdomain: "alice")

    @user_b = User.create!(
      email: "bob@example.com",
      username: "bob",
      password: "password123",
      password_confirmation: "password123"
    )
    @webstead_b = Webstead.create!(user: @user_b, subdomain: "bobsite")

    @post_a = Post.create!(webstead: @webstead_a, title: "Alice Post", body: "Alice content")
    @post_a.update_column(:published_at, 1.day.ago)
    @post_b = Post.create!(webstead: @webstead_b, title: "Bob Post", body: "Bob content")
    @post_b.update_column(:published_at, 1.day.ago)
  end

  test "subdomain routing sets correct Current.webstead" do
    get posts_url, headers: { "Host" => "alice.webstead.test" }
    assert_response :success
    assert_equal @webstead_a, Current.webstead
  end

  test "posts from webstead A not visible when accessing webstead B" do
    get posts_url, headers: { "Host" => "alice.webstead.test" }
    assert_response :success
    assert_includes response.body, "Alice Post"
    assert_not_includes response.body, "Bob Post"

    get posts_url, headers: { "Host" => "bobsite.webstead.test" }
    assert_response :success
    assert_includes response.body, "Bob Post"
    assert_not_includes response.body, "Alice Post"
  end

  test "custom domain routing sets correct Current.webstead" do
    @webstead_a.update!(custom_domain: "alice.example.com")
    get posts_url, headers: { "Host" => "alice.example.com" }
    assert_response :success
    assert_equal @webstead_a, Current.webstead
  end

  test "nonexistent webstead returns 404" do
    get posts_url, headers: { "Host" => "nonexistent.webstead.test" }
    assert_response :not_found
  end
end
