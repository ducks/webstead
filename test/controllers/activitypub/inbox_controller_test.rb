# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module ActivityPub
  class InboxControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @user = User.create!(
        email: "inboxtest@example.com",
        username: "inboxuser",
        password: "password123",
        password_confirmation: "password123"
      )
      @webstead = Webstead.create!(user: @user, subdomain: "inboxtest")
      Current.webstead = @webstead

      # Generate real RSA keypair for signature tests
      @remote_keypair = OpenSSL::PKey::RSA.new(2048)
      @remote_actor_uri = "https://mastodon.example/users/remoteuser"
      @remote_inbox_url = "https://mastodon.example/users/remoteuser/inbox"
      @remote_shared_inbox_url = "https://mastodon.example/inbox"

      @remote_actor_document = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Person",
        "id" => @remote_actor_uri,
        "preferredUsername" => "remoteuser",
        "inbox" => @remote_inbox_url,
        "endpoints" => { "sharedInbox" => @remote_shared_inbox_url },
        "publicKey" => {
          "id" => "#{@remote_actor_uri}#main-key",
          "owner" => @remote_actor_uri,
          "publicKeyPem" => @remote_keypair.public_key.to_pem
        }
      }

      @follow_activity = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Follow",
        "id" => "https://mastodon.example/activities/follow-123",
        "actor" => @remote_actor_uri,
        "object" => "https://#{@webstead.primary_domain}/users/#{@user.username}"
      }
    end

    teardown do
      Current.webstead = nil
    end

    def host_header
      { "Host" => "inboxtest.webstead.dev" }
    end

    def inbox_path
      "/users/#{@user.username}/inbox"
    end

    def stub_remote_actor
      stub_request(:get, @remote_actor_uri)
        .to_return(status: 200, body: @remote_actor_document.to_json,
                   headers: { "Content-Type" => "application/activity+json" })
    end

    def sign_request(body, path: inbox_path)
      date = Time.now.utc.httpdate
      digest = "SHA-256=#{Digest::SHA256.base64digest(body)}"

      signed_headers = "(request-target) host date digest"
      signing_string = [
        "(request-target): post #{path}",
        "host: inboxtest.webstead.dev",
        "date: #{date}",
        "digest: #{digest}"
      ].join("\n")

      signature = @remote_keypair.sign(OpenSSL::Digest::SHA256.new, signing_string)
      signature_b64 = Base64.strict_encode64(signature)

      {
        "Date" => date,
        "Digest" => digest,
        "Signature" => "keyId=\"#{@remote_actor_uri}#main-key\",algorithm=\"rsa-sha256\",headers=\"#{signed_headers}\",signature=\"#{signature_b64}\""
      }
    end

    def post_to_inbox(activity: @follow_activity, sign: true, extra_headers: {})
      body = activity.to_json
      request_headers = host_header.merge(
        "Content-Type" => "application/activity+json"
      ).merge(extra_headers)

      if sign
        request_headers.merge!(sign_request(body))
      end

      stub_remote_actor

      post inbox_path, params: body, headers: request_headers
    end

    # -- Follow/Accept flow --

    test "successful Follow creates Follower and enqueues Accept delivery" do
      stub_remote_actor

      assert_difference "Follower.unscoped.count", 1 do
        post_to_inbox
      end

      assert_response :accepted
      assert_enqueued_jobs 1, only: ActivityPub::DeliveryJob

      follower = Follower.unscoped.last
      assert_equal @remote_actor_uri, follower.actor_uri
      assert_equal @remote_inbox_url, follower.inbox_url
      assert_equal @remote_shared_inbox_url, follower.shared_inbox_url
      assert_equal @webstead.id, follower.webstead_id
      assert follower.accepted?
    end

    test "successful Follow creates FederatedActor record" do
      assert_difference "FederatedActor.count", 1 do
        post_to_inbox
      end

      assert_response :accepted

      actor = FederatedActor.find_by(actor_uri: @remote_actor_uri)
      assert_not_nil actor
      assert_equal "Person", actor.actor_type
      assert_equal @remote_inbox_url, actor.inbox_url
      assert_equal @remote_shared_inbox_url, actor.shared_inbox_url
      assert_equal "remoteuser", actor.username
      assert_equal "mastodon.example", actor.domain
    end

    # -- Idempotency --

    test "duplicate Follow is idempotent" do
      post_to_inbox
      assert_response :accepted

      assert_no_difference "Follower.unscoped.count" do
        post_to_inbox
      end

      assert_response :accepted
    end

    # -- Signature verification --

    test "missing Signature header returns 400" do
      body = @follow_activity.to_json

      post inbox_path, params: body, headers: host_header.merge(
        "Content-Type" => "application/activity+json"
      )

      assert_response :bad_request
      json = JSON.parse(response.body)
      assert_equal "Missing Signature header", json["error"]
    end

    test "malformed Signature header returns 400" do
      body = @follow_activity.to_json

      post inbox_path, params: body, headers: host_header.merge(
        "Content-Type" => "application/activity+json",
        "Signature" => "garbage-data"
      )

      assert_response :bad_request
      json = JSON.parse(response.body)
      assert_equal "Malformed Signature header", json["error"]
    end

    test "invalid signature returns 401" do
      wrong_keypair = OpenSSL::PKey::RSA.new(2048)
      body = @follow_activity.to_json
      date = Time.now.utc.httpdate
      digest = "SHA-256=#{Digest::SHA256.base64digest(body)}"

      signed_headers = "(request-target) host date digest"
      signing_string = [
        "(request-target): post #{inbox_path}",
        "host: inboxtest.webstead.dev",
        "date: #{date}",
        "digest: #{digest}"
      ].join("\n")

      signature = wrong_keypair.sign(OpenSSL::Digest::SHA256.new, signing_string)
      signature_b64 = Base64.strict_encode64(signature)

      stub_remote_actor

      post inbox_path, params: body, headers: host_header.merge(
        "Content-Type" => "application/activity+json",
        "Date" => date,
        "Digest" => digest,
        "Signature" => "keyId=\"#{@remote_actor_uri}#main-key\",algorithm=\"rsa-sha256\",headers=\"#{signed_headers}\",signature=\"#{signature_b64}\""
      )

      assert_response :unauthorized
    end

    # -- Malformed JSON --

    test "malformed JSON returns 400" do
      ENV["SKIP_SIGNATURE_VERIFICATION"] = "true"

      post inbox_path, params: "not valid json {{{", headers: host_header.merge(
        "Content-Type" => "application/activity+json"
      )

      assert_response :bad_request
      json = JSON.parse(response.body)
      assert_equal "Invalid JSON", json["error"]
    ensure
      ENV.delete("SKIP_SIGNATURE_VERIFICATION")
    end

    test "missing required fields returns 400" do
      incomplete_activity = { "@context" => "https://www.w3.org/ns/activitystreams" }

      post_to_inbox(activity: incomplete_activity)

      assert_response :bad_request
      json = JSON.parse(response.body)
      assert_match(/Missing required fields/, json["error"])
    end

    # -- Non-Follow activity --

    test "non-Follow activity returns 501 Not Implemented" do
      like_activity = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Like",
        "actor" => @remote_actor_uri,
        "object" => "https://#{@webstead.primary_domain}/posts/1"
      }

      post_to_inbox(activity: like_activity)

      assert_response :not_implemented
      json = JSON.parse(response.body)
      assert_equal "Activity type not supported in v1", json["error"]
    end

    # -- Object URI mismatch --

    test "Follow with mismatched object URI returns 400" do
      bad_follow = @follow_activity.merge(
        "object" => "https://other.example/users/someone"
      )

      post_to_inbox(activity: bad_follow)

      assert_response :bad_request
      json = JSON.parse(response.body)
      assert_equal "Object URI does not match user", json["error"]
    end

    # -- User not found --

    test "inbox for nonexistent user returns 404" do
      body = @follow_activity.to_json
      sig_headers = sign_request(body, path: "/users/nonexistent/inbox")

      stub_remote_actor

      post "/users/nonexistent/inbox", params: body, headers: host_header.merge(
        "Content-Type" => "application/activity+json"
      ).merge(sig_headers)

      assert_response :not_found
    end

    # -- Actor fetch failure --

    test "Follow when remote actor fetch fails returns 503" do
      # Use cache: :null_store in test, so no caching between verify_signature
      # and handle_follow. Both will hit the stub.
      # First call (verify_signature) succeeds, second (handle_follow) fails.
      stub_request(:get, @remote_actor_uri)
        .to_return(
          { status: 200, body: @remote_actor_document.to_json, headers: { "Content-Type" => "application/activity+json" } },
          { status: 500, body: "Internal Server Error" }
        )

      body = @follow_activity.to_json
      sig_headers = sign_request(body)

      post inbox_path, params: body, headers: host_header.merge(
        "Content-Type" => "application/activity+json"
      ).merge(sig_headers)

      assert_response :service_unavailable
    end

    # -- Signature skip in test mode --

    test "SKIP_SIGNATURE_VERIFICATION allows unsigned requests in test" do
      ENV["SKIP_SIGNATURE_VERIFICATION"] = "true"

      stub_remote_actor

      assert_difference "Follower.unscoped.count", 1 do
        body = @follow_activity.to_json
        post inbox_path, params: body, headers: host_header.merge(
          "Content-Type" => "application/activity+json"
        )
      end

      assert_response :accepted
    ensure
      ENV.delete("SKIP_SIGNATURE_VERIFICATION")
    end
  end
end
