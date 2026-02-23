# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActivityPub Inbox', type: :request do
  let(:user) { User.create!(username: 'alice', email: 'alice@example.com', password: 'password123') }
  let(:webstead) do
    keypair = OpenSSL::PKey::RSA.new(2048)
    Webstead.create!(
      subdomain: 'alice',
      user: user,
      private_key: keypair.to_pem,
      public_key: keypair.public_key.to_pem
    )
  end

  let(:remote_actor_uri) { 'https://mastodon.example/@bob' }
  let(:remote_keypair) { OpenSSL::PKey::RSA.new(2048) }
  let(:remote_actor_document) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'type' => 'Person',
      'id' => remote_actor_uri,
      'preferredUsername' => 'bob',
      'inbox' => 'https://mastodon.example/@bob/inbox',
      'publicKey' => {
        'id' => "#{remote_actor_uri}#main-key",
        'owner' => remote_actor_uri,
        'publicKeyPem' => remote_keypair.public_key.to_pem
      },
      'endpoints' => {
        'sharedInbox' => 'https://mastodon.example/inbox'
      }
    }
  end

  let(:follow_activity) do
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'type' => 'Follow',
      'id' => 'https://mastodon.example/follows/123',
      'actor' => remote_actor_uri,
      'object' => "https://#{webstead.primary_domain}/users/#{user.username}"
    }
  end

  before do
    stub_request(:get, remote_actor_uri)
      .to_return(
        status: 200,
        body: remote_actor_document.to_json,
        headers: { 'Content-Type' => 'application/activity+json' }
      )
  end

  def sign_and_post(activity, private_key, key_id)
    body = activity.to_json
    digest = Digest::SHA256.base64digest(body)
    date = Time.now.utc.httpdate
    host = webstead.primary_domain
    path = "/activitypub/users/#{user.username}/inbox"

    signing_string = [
      "(request-target): post #{path}",
      "host: #{host}",
      "date: #{date}",
      "digest: SHA-256=#{digest}"
    ].join("\n")

    signature = private_key.sign(OpenSSL::Digest::SHA256.new, signing_string)
    signature_base64 = Base64.strict_encode64(signature)
    signature_header = "keyId=\"#{key_id}\",headers=\"(request-target) host date digest\",signature=\"#{signature_base64}\""

    post path,
         params: body,
         headers: {
           'Content-Type' => 'application/activity+json',
           'Host' => host,
           'Date' => date,
           'Digest' => "SHA-256=#{digest}",
           'Signature' => signature_header
         },
         as: :json
  end

  describe 'POST /activitypub/users/:username/inbox' do
    context 'with valid Follow activity and signature' do
      it 'creates follower and enqueues Accept delivery' do
        expect do
          sign_and_post(follow_activity, remote_keypair, "#{remote_actor_uri}#main-key")
        end.to change(Follower, :count).by(1)
          .and have_enqueued_job(ActivityPub::DeliveryJob)

        expect(response).to have_http_status(:accepted)

        follower = Follower.last
        expect(follower.webstead).to eq(webstead)
        expect(follower.federated_actor.actor_uri).to eq(remote_actor_uri)
        expect(follower.status).to eq('accepted')
      end
    end

    context 'with duplicate Follow' do
      it 'is idempotent' do
        sign_and_post(follow_activity, remote_keypair, "#{remote_actor_uri}#main-key")

        expect do
          sign_and_post(follow_activity, remote_keypair, "#{remote_actor_uri}#main-key")
        end.not_to change(Follower, :count)

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with invalid signature' do
      it 'returns 401 Unauthorized' do
        wrong_keypair = OpenSSL::PKey::RSA.new(2048)
        sign_and_post(follow_activity, wrong_keypair, "#{remote_actor_uri}#main-key")

        expect(response).to have_http_status(:unauthorized)
        expect(Follower.count).to eq(0)
      end
    end

    context 'without signature header' do
      it 'returns 400 Bad Request' do
        post "/activitypub/users/#{user.username}/inbox",
             params: follow_activity.to_json,
             headers: { 'Content-Type' => 'application/activity+json' }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to include('Missing Signature header')
      end
    end

    context 'with malformed JSON' do
      it 'returns 400 Bad Request' do
        post "/activitypub/users/#{user.username}/inbox",
             params: 'not json',
             headers: {
               'Content-Type' => 'application/activity+json',
               'Signature' => 'dummy'
             }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with non-Follow activity' do
      it 'returns 501 Not Implemented' do
        like_activity = follow_activity.merge('type' => 'Like')
        sign_and_post(like_activity, remote_keypair, "#{remote_actor_uri}#main-key")

        expect(response).to have_http_status(:not_implemented)
        expect(JSON.parse(response.body)['error']).to include('not supported')
      end
    end

    context 'with missing required fields' do
      it 'returns 400 Bad Request' do
        invalid_activity = { 'type' => 'Follow' }
        sign_and_post(invalid_activity, remote_keypair, "#{remote_actor_uri}#main-key")

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to include('Missing required fields')
      end
    end

    context 'when actor fetch fails' do
      it 'returns 503 Service Unavailable' do
        stub_request(:get, remote_actor_uri).to_return(status: 500)

        sign_and_post(follow_activity, remote_keypair, "#{remote_actor_uri}#main-key")

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
