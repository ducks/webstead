# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::HttpSignatureService do
  let(:webstead) { create(:webstead, subdomain: 'alice') }
  let(:key_id) { "#{webstead.actor_uri}#main-key" }
  let(:private_key_pem) { webstead.private_key }
  let(:uri) { URI.parse('https://mastodon.social/users/bob/inbox') }
  let(:request) { Net::HTTP::Post.new(uri) }

  describe '.sign' do
    it 'adds Date header' do
      described_class.sign(request, uri, key_id, private_key_pem)
      expect(request['Date']).to match(/\w+, \d+ \w+ \d{4} \d{2}:\d{2}:\d{2} GMT/)
    end

    it 'adds Host header' do
      described_class.sign(request, uri, key_id, private_key_pem)
      expect(request['Host']).to eq('mastodon.social')
    end

    it 'adds Digest header for POST requests' do
      request.body = '{"type":"Follow"}'
      described_class.sign(request, uri, key_id, private_key_pem)
      expect(request['Digest']).to start_with('SHA-256=')
    end

    it 'adds Signature header' do
      request.body = '{"type":"Follow"}'
      described_class.sign(request, uri, key_id, private_key_pem)
      expect(request['Signature']).to include('keyId=')
      expect(request['Signature']).to include('algorithm="rsa-sha256"')
      expect(request['Signature']).to include('headers=')
      expect(request['Signature']).to include('signature=')
    end

    it 'includes correct headers in signature' do
      request.body = '{"type":"Follow"}'
      described_class.sign(request, uri, key_id, private_key_pem)
      expect(request['Signature']).to include('headers="(request-target) host date digest"')
    end

    it 'generates valid signature that can be verified' do
      request.body = '{"type":"Follow"}'
      described_class.sign(request, uri, key_id, private_key_pem)

      # Extract signature from Signature header
      signature_match = request['Signature'].match(/signature=\"([^\"]+)\"/)
      signature_base64 = signature_match[1]
      signature = Base64.strict_decode64(signature_base64)

      # Reconstruct signing string
      signing_string = [
        "(request-target): post #{uri.request_uri}",
        "host: #{request['Host']}",
        "date: #{request['Date']}",
        "digest: #{request['Digest']}"
      ].join("\n")

      # Verify with public key
      public_key = webstead.public_key_object
      verified = public_key.verify(
        OpenSSL::Digest::SHA256.new,
        signature,
        signing_string
      )

      expect(verified).to be true
    end

    it 'generates different signatures for different bodies' do
      request.body = '{"type":"Follow"}'
      described_class.sign(request, uri, key_id, private_key_pem)
      sig1 = request['Signature']

      request2 = Net::HTTP::Post.new(uri)
      request2.body = '{"type":"Accept"}'
      described_class.sign(request2, uri, key_id, private_key_pem)
      sig2 = request2['Signature']

      expect(sig1).not_to eq(sig2)
    end
  end
end
