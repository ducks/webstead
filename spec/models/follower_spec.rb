require "rails_helper"

RSpec.describe Follower, type: :model do
  fab!(:user) { User.create!(email: "test@example.com", username: "testuser", password: "password123") }
  fab!(:webstead) { Webstead.create!(subdomain: "test", user: user) }

  before do
    Current.webstead_id = webstead.id
  end

  after do
    Current.webstead_id = nil
  end

  describe "validations" do
    it "requires actor_uri" do
      follower = Follower.new(inbox_url: "https://mastodon.social/users/test/inbox")
      expect(follower).not_to be_valid
      expect(follower.errors[:actor_uri]).to include("can't be blank")
    end

    it "requires inbox_url" do
      follower = Follower.new(actor_uri: "https://mastodon.social/users/test")
      expect(follower).not_to be_valid
      expect(follower.errors[:inbox_url]).to include("can't be blank")
    end

    it "validates actor_uri is a valid HTTP(S) URL" do
      follower = Follower.new(actor_uri: "not-a-url", inbox_url: "https://mastodon.social/inbox")
      expect(follower).not_to be_valid
      expect(follower.errors[:actor_uri]).to include("must be a valid HTTP(S) URL")
    end

    it "validates inbox_url is a valid HTTP(S) URL" do
      follower = Follower.new(actor_uri: "https://mastodon.social/users/test", inbox_url: "not-a-url")
      expect(follower).not_to be_valid
      expect(follower.errors[:inbox_url]).to include("must be a valid HTTP(S) URL")
    end

    it "validates shared_inbox_url is a valid HTTP(S) URL when present" do
      follower = Follower.new(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox",
        shared_inbox_url: "not-a-url"
      )
      expect(follower).not_to be_valid
      expect(follower.errors[:shared_inbox_url]).to be_present
    end

    it "allows blank shared_inbox_url" do
      follower = Follower.new(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox",
        shared_inbox_url: ""
      )
      expect(follower).to be_valid
    end

    it "prevents duplicate followers for same webstead" do
      Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )

      duplicate = Follower.new(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:actor_uri]).to include("is already following this webstead")
    end

    it "allows same actor to follow different websteads" do
      other_webstead = Webstead.create!(subdomain: "other", user: user)

      Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )

      Current.webstead_id = other_webstead.id
      other_follower = Follower.new(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )
      expect(other_follower).to be_valid
    end
  end

  describe "associations" do
    it "belongs to webstead" do
      follower = Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )
      expect(follower.webstead).to eq(webstead)
    end

    it "is destroyed when webstead is destroyed" do
      Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )
      expect { webstead.destroy }.to change(Follower, :count).by(-1)
    end
  end

  describe "tenant scoping" do
    it "automatically scopes to Current.webstead_id" do
      follower = Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )

      expect(Follower.all).to include(follower)

      other_webstead = Webstead.create!(subdomain: "other", user: user)
      Current.webstead_id = other_webstead.id

      expect(Follower.all).not_to include(follower)
    end

    it "automatically assigns webstead_id on create" do
      follower = Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )
      expect(follower.webstead_id).to eq(webstead.id)
    end
  end

  describe "scopes" do
    it "filters accepted followers" do
      accepted = Follower.create!(
        actor_uri: "https://mastodon.social/users/accepted",
        inbox_url: "https://mastodon.social/inbox",
        accepted_at: Time.current
      )
      pending = Follower.create!(
        actor_uri: "https://mastodon.social/users/pending",
        inbox_url: "https://mastodon.social/inbox"
      )

      expect(Follower.accepted).to include(accepted)
      expect(Follower.accepted).not_to include(pending)
    end

    it "filters pending followers" do
      accepted = Follower.create!(
        actor_uri: "https://mastodon.social/users/accepted",
        inbox_url: "https://mastodon.social/inbox",
        accepted_at: Time.current
      )
      pending = Follower.create!(
        actor_uri: "https://mastodon.social/users/pending",
        inbox_url: "https://mastodon.social/inbox"
      )

      expect(Follower.pending).to include(pending)
      expect(Follower.pending).not_to include(accepted)
    end
  end

  describe "helper methods" do
    it "returns true for accepted? when accepted_at is present" do
      follower = Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox",
        accepted_at: Time.current
      )
      expect(follower.accepted?).to be true
    end

    it "returns false for accepted? when accepted_at is nil" do
      follower = Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )
      expect(follower.accepted?).to be false
    end

    it "returns true for pending? when accepted_at is nil" do
      follower = Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )
      expect(follower.pending?).to be true
    end

    it "returns false for pending? when accepted_at is present" do
      follower = Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox",
        accepted_at: Time.current
      )
      expect(follower.pending?).to be false
    end

    it "sets accepted_at to current time with accept!" do
      follower = Follower.create!(
        actor_uri: "https://mastodon.social/users/test",
        inbox_url: "https://mastodon.social/inbox"
      )
      expect(follower.accepted_at).to be_nil

      follower.accept!
      expect(follower.accepted_at).to be_present
      expect(follower.accepted_at).to be_within(1.second).of(Time.current)
    end
  end
end
