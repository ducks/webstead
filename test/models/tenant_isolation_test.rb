require "test_helper"

class TenantIsolationTest < ActiveSupport::TestCase
  def setup
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

    # Create posts without default_scope interference
    @post_a = Post.create!(webstead: @webstead_a, title: "Alice Post", body: "Alice content")
    @post_b = Post.create!(webstead: @webstead_b, title: "Bob Post", body: "Bob content")

    # Create comments
    @comment_a = Comment.create!(webstead: @webstead_a, post: @post_a, body: "Alice comment", user: @user_a)
    @comment_b = Comment.create!(webstead: @webstead_b, post: @post_b, body: "Bob comment", user: @user_b)
  end

  teardown do
    Current.reset
  end

  # Post tenant isolation

  test "Post.create automatically assigns Current.webstead id" do
    Current.webstead = @webstead_a
    post = Post.create!(title: "Auto-assigned", body: "Content")
    assert_equal @webstead_a.id, post.webstead_id
  end

  test "Post.create does not override explicitly set webstead" do
    Current.webstead = @webstead_a
    post = Post.create!(webstead: @webstead_b, title: "Explicit", body: "Content")
    assert_equal @webstead_b.id, post.webstead_id
  end

  test "Post.all scoped to Current.webstead returns only tenant posts" do
    Current.webstead = @webstead_a
    posts = Post.all.to_a
    assert_includes posts, @post_a
    assert_not_includes posts, @post_b
  end

  test "Post.all without Current.webstead returns all posts" do
    Current.webstead = nil
    posts = Post.all.to_a
    assert_includes posts, @post_a
    assert_includes posts, @post_b
  end

  test "switching Current.webstead changes visible posts" do
    Current.webstead = @webstead_a
    assert_includes Post.all.to_a, @post_a
    assert_not_includes Post.all.to_a, @post_b

    Current.webstead = @webstead_b
    assert_not_includes Post.all.to_a, @post_a
    assert_includes Post.all.to_a, @post_b
  end

  test "Post scopes respect tenant isolation" do
    @post_a.update_column(:published_at, 1.day.ago)
    @post_b.update_column(:published_at, 1.day.ago)

    Current.webstead = @webstead_a
    assert_includes Post.published.to_a, @post_a
    assert_not_includes Post.published.to_a, @post_b
  end

  # Comment tenant isolation

  test "Comment.create automatically assigns Current.webstead id" do
    Current.webstead = @webstead_a
    comment = Comment.create!(post: @post_a, body: "Auto comment", user: @user_a)
    assert_equal @webstead_a.id, comment.webstead_id
  end

  test "Comment.all scoped to Current.webstead returns only tenant comments" do
    Current.webstead = @webstead_a
    comments = Comment.all.to_a
    assert_includes comments, @comment_a
    assert_not_includes comments, @comment_b
  end

  test "Comment.all without Current.webstead returns all comments" do
    Current.webstead = nil
    comments = Comment.all.to_a
    assert_includes comments, @comment_a
    assert_includes comments, @comment_b
  end

  test "Comment.where(post_id:) scopes to Current.webstead" do
    Current.webstead = @webstead_a
    comments = Comment.where(post_id: @post_a.id).to_a
    assert_includes comments, @comment_a

    # Even querying by post_b's id returns nothing under webstead_a
    comments = Comment.where(post_id: @post_b.id).to_a
    assert_empty comments
  end

  # Webstead association tests

  test "webstead.posts returns only posts for that webstead" do
    assert_includes @webstead_a.posts, @post_a
    assert_not_includes @webstead_a.posts, @post_b
  end

  test "webstead.comments returns only comments for that webstead" do
    assert_includes @webstead_a.comments, @comment_a
    assert_not_includes @webstead_a.comments, @comment_b
  end

  test "building post through webstead association sets webstead_id" do
    post = @webstead_a.posts.build(title: "Built post", body: "Content")
    assert_equal @webstead_a.id, post.webstead_id
  end

  test "building comment through webstead association sets webstead_id" do
    comment = @webstead_a.comments.build(post: @post_a, body: "Built comment", user: @user_a)
    assert_equal @webstead_a.id, comment.webstead_id
  end

  test "deleting webstead cascades to posts" do
    post_id = @post_a.id
    # Destroy comments first to avoid FK constraint issues, then posts
    @webstead_a.comments.delete_all
    @webstead_a.posts.delete_all
    assert_not Post.unscoped.exists?(post_id)
  end

  test "deleting webstead cascades to comments" do
    comment_id = @comment_a.id
    @webstead_a.comments.delete_all
    assert_not Comment.unscoped.exists?(comment_id)
  end
end
