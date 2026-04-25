require "test_helper"

class TenantIsolationIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    suffix = SecureRandom.hex(4)
    @user_a = User.create!(
      email: "alice_#{suffix}@example.com",
      username: "alice_#{suffix}",
      password: "password123",
      password_confirmation: "password123"
    )
    @webstead_a = Webstead.create!(user: @user_a, subdomain: "testusera#{suffix}")

    @user_b = User.create!(
      email: "bob_#{suffix}@example.com",
      username: "bob_#{suffix}",
      password: "password123",
      password_confirmation: "password123"
    )
    @webstead_b = Webstead.create!(user: @user_b, subdomain: "bobsite#{suffix}")

    @post_a = Post.create!(webstead: @webstead_a, title: "Alice Post", body: "Alice content")
    @post_a.update_column(:published_at, 1.day.ago)
    @post_b = Post.create!(webstead: @webstead_b, title: "Bob Post", body: "Bob content")
    @post_b.update_column(:published_at, 1.day.ago)
  end

  test "subdomain routing sets correct Current.webstead" do
    get posts_url, headers: { "Host" => "#{@webstead_a.subdomain}.webstead.test" }
    assert_response :success
    assert_equal @webstead_a, Current.webstead
  end

  test "posts from webstead A not visible when accessing webstead B" do
    get posts_url, headers: { "Host" => "#{@webstead_a.subdomain}.webstead.test" }
    assert_response :success
    assert_includes response.body, "Alice Post"
    assert_not_includes response.body, "Bob Post"

    get posts_url, headers: { "Host" => "#{@webstead_b.subdomain}.webstead.test" }
    assert_response :success
    assert_includes response.body, "Bob Post"
    assert_not_includes response.body, "Alice Post"
  end

  test "custom domain routing sets correct Current.webstead" do
    # Use SQL update to bypass encryption issues in test environment
    Webstead.where(id: @webstead_a.id).update_all(custom_domain: "alice.example.com")
    get posts_url, headers: { "Host" => "alice.example.com" }
    assert_response :success
    # Verify by subdomain instead since reload triggers encryption errors
    assert_equal @webstead_a.subdomain, Current.webstead&.subdomain
  end

  test "nonexistent webstead returns 404" do
    get posts_url, headers: { "Host" => "nonexistent.webstead.test" }
    assert_response :not_found
  end
end
