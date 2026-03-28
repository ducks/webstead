# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module ActivityPub
  class FederatePostJobTest < ActiveJob::TestCase
    setup do
      @user = User.create!(
        email: "test@example.com",
        username: "testuser",
        password: "password123"
      )
      @webstead = Webstead.create!(
        subdomain: "fedtest",
        user: @user
      )
      @webstead.generate_keypair! if !@webstead.private_key_pem.present?

      Current.webstead = @webstead

      @follower = Follower.create!(
        webstead: @webstead,
        actor_uri: "https://mastodon.example/@follower",
        inbox_url: "https://mastodon.example/inbox",
        shared_inbox_url: "https://mastodon.example/shared-inbox",
        accepted_at: Time.current
      )

      @post = Post.create!(
        webstead: @webstead,
        title: "Test Post",
        body: "This is a **test** post.",
        published_at: Time.current
      )
    end

    teardown do
      Current.webstead = nil
    end

    test "delivers Create activity to follower shared inbox" do
      stub_request(:post, "https://mastodon.example/shared-inbox")
        .to_return(status: 202)

      FederatePostJob.perform_now(@post.id)

      assert_requested :post, "https://mastodon.example/shared-inbox" do |req|
        body = JSON.parse(req.body)
        assert_equal "Create", body["type"]
        assert_equal @webstead.actor_uri, body["actor"]
        assert_equal "Note", body["object"]["type"]
        assert_includes body["object"]["content"], "<strong>test</strong>"
      end
    end

    test "delivers to individual inbox if shared inbox not available" do
      @follower.update!(shared_inbox_url: nil)

      stub_request(:post, "https://mastodon.example/inbox")
        .to_return(status: 202)

      FederatePostJob.perform_now(@post.id)

      assert_requested :post, "https://mastodon.example/inbox"
    end

    test "skips delivery for draft posts" do
      @post.update_columns(published_at: nil)

      FederatePostJob.perform_now(@post.id)

      assert_not_requested :post, /.*/
    end

    test "skips delivery when no followers" do
      @follower.destroy

      FederatePostJob.perform_now(@post.id)

      assert_not_requested :post, /.*/
    end

    test "handles delivery failure for individual follower" do
      stub_request(:post, "https://mastodon.example/shared-inbox")
        .to_return(status: 500, body: "Internal Server Error")

      assert_nothing_raised do
        FederatePostJob.perform_now(@post.id)
      end

      assert_requested :post, "https://mastodon.example/shared-inbox"
    end

    test "includes HTTP Signature header in request" do
      stub_request(:post, "https://mastodon.example/shared-inbox")
        .to_return(status: 202)

      FederatePostJob.perform_now(@post.id)

      assert_requested :post, "https://mastodon.example/shared-inbox" do |req|
        assert req.headers["Signature"].present?
        assert req.headers["Digest"].present?
      end
    end

    test "renders markdown to HTML in Note content" do
      stub_request(:post, "https://mastodon.example/shared-inbox")
        .to_return(status: 202)

      FederatePostJob.perform_now(@post.id)

      assert_requested :post, "https://mastodon.example/shared-inbox" do |req|
        body = JSON.parse(req.body)
        content = body["object"]["content"]
        assert_includes content, "<strong>test</strong>"
        assert_includes content, "<p>"
      end
    end
  end
end
