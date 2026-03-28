require "test_helper"

class FollowerTest < ActiveSupport::TestCase
  def setup
    @webstead = websteads(:alice)
    Current.webstead = @webstead
    @follower = Follower.new(
      webstead: @webstead,
      actor_uri: "https://example.social/users/newuser",
      inbox_url: "https://example.social/users/newuser/inbox",
      shared_inbox_url: "https://example.social/inbox"
    )
  end

  def teardown
    Current.webstead = nil
  end

  # Validations

  test "valid follower" do
    assert @follower.valid?
  end

  test "requires actor_uri" do
    @follower.actor_uri = nil
    assert_not @follower.valid?
    assert_includes @follower.errors[:actor_uri], "can't be blank"
  end

  test "requires inbox_url" do
    @follower.inbox_url = nil
    assert_not @follower.valid?
    assert_includes @follower.errors[:inbox_url], "can't be blank"
  end

  test "actor_uri must be a valid HTTP(S) URL" do
    @follower.actor_uri = "ftp://example.com/user"
    assert_not @follower.valid?
    assert_includes @follower.errors[:actor_uri], "must be a valid HTTP(S) URL"

    @follower.actor_uri = "not-a-url"
    assert_not @follower.valid?

    @follower.actor_uri = "https://mastodon.social/users/test"
    assert @follower.valid?

    @follower.actor_uri = "http://mastodon.social/users/test"
    assert @follower.valid?
  end

  test "inbox_url must be a valid HTTP(S) URL" do
    @follower.inbox_url = "ftp://example.com/inbox"
    assert_not @follower.valid?
    assert_includes @follower.errors[:inbox_url], "must be a valid HTTP(S) URL"
  end

  test "shared_inbox_url must be a valid HTTP(S) URL when present" do
    @follower.shared_inbox_url = "ftp://example.com/inbox"
    assert_not @follower.valid?
    assert_includes @follower.errors[:shared_inbox_url], "must be a valid HTTP(S) URL"
  end

  test "shared_inbox_url can be blank" do
    @follower.shared_inbox_url = nil
    assert @follower.valid?

    @follower.shared_inbox_url = ""
    assert @follower.valid?
  end

  test "actor_uri must be unique per webstead" do
    @follower.save!
    duplicate = Follower.new(
      webstead: @webstead,
      actor_uri: @follower.actor_uri,
      inbox_url: "https://example.social/users/newuser/inbox"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:actor_uri], "is already following this webstead"
  end

  test "same actor_uri can follow different websteads" do
    @follower.save!
    bob_webstead = websteads(:bob)
    Current.webstead = bob_webstead
    other = Follower.new(
      webstead: bob_webstead,
      actor_uri: @follower.actor_uri,
      inbox_url: @follower.inbox_url
    )
    assert other.valid?
  end

  # Associations

  test "belongs to webstead" do
    assert_equal @webstead, @follower.webstead
  end

  test "webstead has many followers" do
    assert_respond_to @webstead, :followers
  end

  test "destroying webstead destroys followers" do
    user = @webstead.user
    @follower.save!
    follower_id = @follower.id

    Current.webstead = nil
    @webstead.destroy!
    assert_not Follower.unscoped.exists?(follower_id)
  end

  # Scopes

  test "accepted scope returns followers with accepted_at" do
    accepted = followers(:mastodon_follower)
    pending = followers(:pending_follower)

    results = Follower.accepted
    assert_includes results, accepted
    assert_not_includes results, pending
  end

  test "pending scope returns followers without accepted_at" do
    accepted = followers(:mastodon_follower)
    pending = followers(:pending_follower)

    results = Follower.pending
    assert_not_includes results, accepted
    assert_includes results, pending
  end

  # Helper methods

  test "accepted? returns true when accepted_at is present" do
    @follower.accepted_at = Time.current
    assert @follower.accepted?
  end

  test "accepted? returns false when accepted_at is nil" do
    @follower.accepted_at = nil
    assert_not @follower.accepted?
  end

  test "pending? returns true when accepted_at is nil" do
    @follower.accepted_at = nil
    assert @follower.pending?
  end

  test "pending? returns false when accepted_at is present" do
    @follower.accepted_at = Time.current
    assert_not @follower.pending?
  end

  test "accept! sets accepted_at" do
    @follower.save!
    assert_nil @follower.accepted_at

    @follower.accept!
    assert_not_nil @follower.reload.accepted_at
    assert @follower.accepted?
  end

  # Tenant scoping

  test "auto-assigns webstead_id from Current on create" do
    follower = Follower.new(
      actor_uri: "https://remote.social/users/auto",
      inbox_url: "https://remote.social/users/auto/inbox"
    )
    follower.valid?
    assert_equal @webstead.id, follower.webstead_id
  end

  test "default scope filters by Current.webstead" do
    alice_followers = Follower.all.to_a
    alice_followers.each do |f|
      assert_equal @webstead.id, f.webstead_id
    end

    bob_webstead = websteads(:bob)
    Current.webstead = bob_webstead
    bob_followers = Follower.all.to_a
    bob_followers.each do |f|
      assert_equal bob_webstead.id, f.webstead_id
    end
  end
end
