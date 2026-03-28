require "test_helper"

class CommentTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "commenter@example.com",
      username: "commenter",
      password: "password123",
      password_confirmation: "password123"
    )
    @webstead = Webstead.create!(user: @user, subdomain: "commenttest")
    @post = Post.create!(webstead: @webstead, title: "Test Post", body: "Test content")
    Current.webstead = @webstead
  end

  def teardown
    Current.webstead = nil
  end

  def build_comment(**attrs)
    Comment.new({
      body: "A test comment",
      post: @post,
      webstead: @webstead,
      user: @user
    }.merge(attrs))
  end

  # -- Validations --

  test "valid comment with user" do
    comment = build_comment
    assert comment.valid?, comment.errors.full_messages.join(", ")
  end

  test "valid comment with federated actor" do
    actor = FederatedActor.create!(
      actor_uri: "https://remote.example.com/users/alice",
      inbox_url: "https://remote.example.com/users/alice/inbox",
      username: "alice"
    )
    comment = build_comment(user: nil, federated_actor: actor)
    assert comment.valid?, comment.errors.full_messages.join(", ")
  end

  test "requires body" do
    comment = build_comment(body: nil)
    assert_not comment.valid?
    assert_includes comment.errors[:body], "can't be blank"
  end

  test "body must not exceed 10000 characters" do
    comment = build_comment(body: "a" * 10_001)
    assert_not comment.valid?
  end

  test "body at 10000 characters is valid" do
    comment = build_comment(body: "a" * 10_000)
    assert comment.valid?
  end

  test "requires post_id" do
    comment = build_comment(post: nil)
    assert_not comment.valid?
  end

  test "requires webstead_id" do
    Current.webstead = nil
    comment = build_comment(webstead: nil)
    comment.webstead_id = nil
    assert_not comment.valid?
    assert_includes comment.errors[:webstead_id], "can't be blank"
    Current.webstead = @webstead
  end

  # -- Exactly-one-author validation --

  test "invalid with both user_id and federated_actor_id" do
    actor = FederatedActor.create!(
      actor_uri: "https://remote.example.com/users/bob",
      inbox_url: "https://remote.example.com/users/bob/inbox",
      username: "bob"
    )
    comment = build_comment(user: @user, federated_actor: actor)
    assert_not comment.valid?
    assert_includes comment.errors[:base], "Comment cannot have both user_id and federated_actor_id"
  end

  test "invalid with neither user_id nor federated_actor_id" do
    comment = build_comment(user: nil, federated_actor: nil)
    assert_not comment.valid?
    assert_includes comment.errors[:base], "Comment must have either user_id or federated_actor_id"
  end

  # -- Associations --

  test "belongs to post" do
    comment = build_comment
    comment.save!
    assert_equal @post, comment.post
  end

  test "belongs to webstead" do
    comment = build_comment
    comment.save!
    assert_equal @webstead, comment.webstead
  end

  test "belongs to user (optional)" do
    comment = build_comment
    comment.save!
    assert_equal @user, comment.user
  end

  test "belongs to parent (optional)" do
    parent = build_comment
    parent.save!

    child = build_comment(parent: parent)
    child.save!

    assert_equal parent, child.parent
  end

  test "has many replies" do
    parent = build_comment
    parent.save!

    child1 = build_comment(parent: parent)
    child1.save!
    child2 = build_comment(parent: parent)
    child2.save!

    assert_equal 2, parent.replies.count
    assert_includes parent.replies, child1
    assert_includes parent.replies, child2
  end

  # -- Scopes --

  test "root_comments returns only top-level comments" do
    root = build_comment
    root.save!

    child = build_comment(parent: root)
    child.save!

    roots = Comment.root_comments
    assert_includes roots, root
    assert_not_includes roots, child
  end

  test "chronological orders by created_at asc" do
    old = build_comment(body: "old")
    old.save!

    new_comment = build_comment(body: "new")
    new_comment.save!

    ordered = Comment.chronological.to_a
    assert_equal old, ordered.first
    assert_equal new_comment, ordered.last
  end

  # -- Helper methods --

  test "author_name returns user display_name for local user" do
    comment = build_comment
    comment.save!
    assert_equal @user.display_name, comment.author_name
  end

  test "author_name returns federated actor info" do
    actor = FederatedActor.create!(
      actor_uri: "https://remote.example.com/users/carol",
      inbox_url: "https://remote.example.com/users/carol/inbox",
      username: "carol",
      display_name: "Carol"
    )
    comment = build_comment(user: nil, federated_actor: actor)
    comment.save!
    assert_equal "Carol", comment.author_name
  end

  test "author_name falls back to username for federated actor without display_name" do
    actor = FederatedActor.create!(
      actor_uri: "https://remote.example.com/users/dave",
      inbox_url: "https://remote.example.com/users/dave/inbox",
      username: "dave"
    )
    comment = build_comment(user: nil, federated_actor: actor)
    comment.save!
    assert_equal "dave", comment.author_name
  end

  test "root? returns true for top-level comments" do
    comment = build_comment
    comment.save!
    assert comment.root?
  end

  test "root? returns false for replies" do
    parent = build_comment
    parent.save!

    child = build_comment(parent: parent)
    child.save!
    assert_not child.root?
  end

  test "depth returns 0 for root comments" do
    comment = build_comment
    comment.save!
    assert_equal 0, comment.depth
  end

  test "depth returns correct nesting level" do
    root = build_comment
    root.save!

    child = build_comment(parent: root)
    child.save!

    grandchild = build_comment(parent: child)
    grandchild.save!

    assert_equal 0, root.depth
    assert_equal 1, child.depth
    assert_equal 2, grandchild.depth
  end

  # -- Cascade deletes --

  test "deleting parent cascades to child comments" do
    parent = build_comment
    parent.save!

    child = build_comment(parent: parent)
    child.save!

    assert_difference "Comment.unscoped.count", -2 do
      parent.destroy
    end
  end

  test "deleting post cascades to comments" do
    comment = build_comment
    comment.save!

    assert_difference "Comment.unscoped.count", -1 do
      @post.destroy
    end
  end

  # -- Auto-assign webstead --

  test "auto-assigns webstead_id from Current.webstead" do
    comment = Comment.new(
      body: "Auto webstead test",
      post: @post,
      user: @user
    )
    comment.valid?
    assert_equal @webstead.id, comment.webstead_id
  end
end
