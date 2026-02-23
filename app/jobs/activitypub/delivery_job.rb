# frozen_string_literal: true

module ActivityPub
  class DeliveryJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(activity:, inbox_url:, signing_key:, signing_key_id:)
      uri = URI.parse(inbox_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/activity+json'
      request['Accept'] = 'application/activity+json'
      request['Date'] = Time.now.utc.httpdate
      request['Host'] = uri.host

      body = activity.to_json
      request.body = body

      # Generate digest
      digest = Digest::SHA256.base64digest(body)
      request['Digest'] = "SHA-256=#{digest}"

      # Sign request
      signature = sign_request(request, uri, signing_key, signing_key_id)
      request['Signature'] = signature

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        Rails.logger.info("[ActivityPub] Delivered activity to #{inbox_url}: #{response.code}")
      else
        Rails.logger.error("[ActivityPub] Delivery failed to #{inbox_url}: #{response.code} #{response.body}")
        raise "Delivery failed: #{response.code}"
      end
    rescue StandardError => e
      Rails.logger.error("[ActivityPub] Delivery error to #{inbox_url}: #{e.message}")
      raise
    end

    private

    def sign_request(request, uri, private_key_pem, key_id)
      headers = '(request-target) host date digest'
      signing_string = [
        "(request-target): post #{uri.request_uri}",
        "host: #{request['Host']}",
        "date: #{request['Date']}",
        "digest: #{request['Digest']}"
      ].join("\n")

      private_key = OpenSSL::PKey::RSA.new(private_key_pem)
      signature = private_key.sign(OpenSSL::Digest::SHA256.new, signing_string)
      signature_base64 = Base64.strict_encode64(signature)

      "keyId=\"#{key_id}\",headers=\"#{headers}\",signature=\"#{signature_base64}\""
    end
  end
end
