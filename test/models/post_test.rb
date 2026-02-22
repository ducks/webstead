require "test_helper"

class PostTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @webstead = Webstead.create!(user: @user, subdomain: "testuser")
    @post = Post.new(webstead: @webstead, title: "Test Post", body: "Test content")
  end

  test "valid post with title and body" do
    assert @post.valid?
  end

  test "requires title" do
    @post.title = nil
    assert_not @post.valid?
    assert_includes @post.errors[:title], "can't be blank"
  end

  test "title must be between 1 and 300 characters" do
    @post.title = ""
    assert_not @post.valid?

    @post.title = "a" * 301
    assert_not @post.valid?

    @post.title = "a" * 300
    assert @post.valid?
  end

  test "draft posts can have blank body" do
    @post.body = ""
    @post.published_at = nil
    assert @post.valid?
  end

  test "published posts require body" do
    @post.body = ""
    @post.published_at = Time.current
    assert_not @post.valid?
    assert_includes @post.errors[:body], "can't be blank for published posts"
  end

  test "draft scope returns unpublished posts" do
    draft = Post.create!(webstead: @webstead, title: "Draft", body: "Draft content")
    published = Post.create!(webstead: @webstead, title: "Published", body: "Published content", published_at: 1.day.ago)

    assert_includes Post.draft, draft
    assert_not_includes Post.draft, published
  end

  test "published scope returns published posts" do
    draft = Post.create!(webstead: @webstead, title: "Draft", body: "Draft content")
    published = Post.create!(webstead: @webstead, title: "Published", body: "Published content", published_at: 1.day.ago)
    future = Post.create!(webstead: @webstead, title: "Future", body: "Future content", published_at: 1.day.from_now)

    assert_not_includes Post.published, draft
    assert_includes Post.published, published
    assert_not_includes Post.published, future
  end

  test "scheduled scope returns future posts" do
    draft = Post.create!(webstead: @webstead, title: "Draft", body: "Draft content")
    published = Post.create!(webstead: @webstead, title: "Published", body: "Published content", published_at: 1.day.ago)
    future = Post.create!(webstead: @webstead, title: "Future", body: "Future content", published_at: 1.day.from_now)

    assert_not_includes Post.scheduled, draft
    assert_not_includes Post.scheduled, published
    assert_includes Post.scheduled, future
  end

  test "recent scope orders by published_at desc then created_at desc" do
    old = Post.create!(webstead: @webstead, title: "Old", body: "Old content", published_at: 3.days.ago)
    new = Post.create!(webstead: @webstead, title: "New", body: "New content", published_at: 1.day.ago)
    draft = Post.create!(webstead: @webstead, title: "Draft", body: "Draft content")

    recent = Post.recent.to_a
    assert_equal new, recent[0]
    assert_equal old, recent[1]
    assert_equal draft, recent[2]
  end

  test "publish! sets published_at and saves" do
    @post.save!
    assert_nil @post.published_at

    @post.publish!
    assert_not_nil @post.published_at
    assert @post.published_at <= Time.current
    assert @post.persisted?
  end

  test "publish! can set custom time" do
    @post.save!
    future_time = 2.days.from_now

    @post.publish!(future_time)
    assert_equal future_time.to_i, @post.published_at.to_i
  end

  test "unpublish! sets published_at to nil" do
    @post.published_at = Time.current
    @post.save!

    @post.unpublish!
    assert_nil @post.published_at
  end

  test "published? returns true for past published_at" do
    @post.published_at = 1.day.ago
    assert @post.published?
  end

  test "published? returns false for nil published_at" do
    @post.published_at = nil
    assert_not @post.published?
  end

  test "published? returns false for future published_at" do
    @post.published_at = 1.day.from_now
    assert_not @post.published?
  end

  test "draft? returns true when published_at is nil" do
    @post.published_at = nil
    assert @post.draft?
  end

  test "draft? returns false when published_at is set" do
    @post.published_at = Time.current
    assert_not @post.draft?
  end

  test "scheduled? returns true for future published_at" do
    @post.published_at = 1.day.from_now
    assert @post.scheduled?
  end

  test "scheduled? returns false for nil published_at" do
    @post.published_at = nil
    assert_not @post.scheduled?
  end

  test "scheduled? returns false for past published_at" do
    @post.published_at = 1.day.ago
    assert_not @post.scheduled?
  end

  test "for_webstead returns only posts for given webstead" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_webstead = Webstead.create!(user: other_user, subdomain: "otheruser")

    post1 = Post.create!(webstead: @webstead, title: "Post 1", body: "Content 1")
    post2 = Post.create!(webstead: other_webstead, title: "Post 2", body: "Content 2")

    webstead_posts = Post.for_webstead(@webstead)
    assert_includes webstead_posts, post1
    assert_not_includes webstead_posts, post2
  end

  test "belongs_to webstead enforces presence" do
    @post.webstead = nil
    assert_not @post.valid?
    assert_includes @post.errors[:webstead], "must exist"
  end
end
