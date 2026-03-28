require "test_helper"

class FederatedActorTest < ActiveSupport::TestCase
  def setup
    @actor = FederatedActor.new(
      actor_uri: "https://mastodon.social/users/testuser",
      inbox_url: "https://mastodon.social/users/testuser/inbox",
      username: "testuser"
    )
  end

  # -- Validations --

  test "valid actor" do
    assert @actor.valid?, @actor.errors.full_messages.join(", ")
  end

  test "requires actor_uri" do
    @actor.actor_uri = nil
    assert_not @actor.valid?
    assert_includes @actor.errors[:actor_uri], "can't be blank"
  end

  test "requires inbox_url" do
    @actor.inbox_url = nil
    assert_not @actor.valid?
    assert_includes @actor.errors[:inbox_url], "can't be blank"
  end

  test "actor_uri must be unique" do
    @actor.save!
    duplicate = FederatedActor.new(
      actor_uri: "https://mastodon.social/users/testuser",
      inbox_url: "https://mastodon.social/users/testuser/inbox",
      username: "duplicate"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:actor_uri], "has already been taken"
  end

  test "actor_uri must be a valid http or https URI" do
    invalid_uris = ["not-a-uri", "ftp://example.com/users/test", ""]

    invalid_uris.each do |uri|
      @actor.actor_uri = uri
      assert_not @actor.valid?, "#{uri.inspect} should be invalid"
    end
  end

  test "inbox_url must be a valid http or https URI" do
    @actor.inbox_url = "not-a-uri"
    assert_not @actor.valid?
  end

  test "shared_inbox_url is optional" do
    @actor.shared_inbox_url = nil
    assert @actor.valid?
  end

  test "shared_inbox_url must be valid URI if present" do
    @actor.shared_inbox_url = "not-a-uri"
    assert_not @actor.valid?
  end

  test "shared_inbox_url accepts valid https URI" do
    @actor.shared_inbox_url = "https://mastodon.social/inbox"
    assert @actor.valid?
  end

  # -- Associations --

  test "has many comments" do
    assert_respond_to @actor, :comments
  end

  # -- stale? method --

  test "stale? returns true when last_fetched_at is nil" do
    @actor.last_fetched_at = nil
    assert @actor.stale?
  end

  test "stale? returns true when last_fetched_at is older than 24 hours" do
    @actor.last_fetched_at = 25.hours.ago
    assert @actor.stale?
  end

  test "stale? returns false when last_fetched_at is recent" do
    @actor.last_fetched_at = 1.hour.ago
    assert_not @actor.stale?
  end

  test "stale? returns false when last_fetched_at is exactly now" do
    @actor.last_fetched_at = Time.current
    assert_not @actor.stale?
  end

  # -- stale scope --

  test "stale scope returns actors with nil last_fetched_at" do
    @actor.save!
    assert_includes FederatedActor.stale, @actor
  end

  test "stale scope returns actors with old last_fetched_at" do
    @actor.last_fetched_at = 25.hours.ago
    @actor.save!
    assert_includes FederatedActor.stale, @actor
  end

  test "stale scope excludes actors with recent last_fetched_at" do
    @actor.last_fetched_at = 1.hour.ago
    @actor.save!
    assert_not_includes FederatedActor.stale, @actor
  end

  # -- fetch_and_cache --

  test "fetch_and_cache returns nil on network failure" do
    original_method = FederatedActor.method(:fetch_actor_document)
    FederatedActor.define_singleton_method(:fetch_actor_document) { |_uri| nil }

    result = FederatedActor.fetch_and_cache("https://remote.example.com/users/nobody")
    assert_nil result
  ensure
    FederatedActor.define_singleton_method(:fetch_actor_document, original_method)
  end
end
