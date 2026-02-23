# frozen_string_literal: true

module ActivityPub
  class DeliveryJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(activity:, inbox_url:, signing_key:, signing_key_id:)
      uri = URI.parse(inbox_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/activity+json"
      request["Accept"] = "application/activity+json"
      request.body = activity.to_json

      # Sign request using HTTP Signatures service
      ActivityPub::HttpSignatureService.sign(request, uri, signing_key_id, signing_key)

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
  end
end
