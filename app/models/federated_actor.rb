class FederatedActor < ApplicationRecord
  has_many :followers, dependent: :destroy

  validates :actor_uri, presence: true,
                        uniqueness: true,
                        format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :inbox_url, presence: true,
                       format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :shared_inbox_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                                        allow_blank: true }

  # Fetch and cache actor data
  def self.fetch_and_cache(actor_uri)
    actor = find_or_initialize_by(actor_uri: actor_uri)

    if actor.new_record? || actor.last_fetched_at.nil? || actor.last_fetched_at < 24.hours.ago
      actor_data = fetch_actor_document(actor_uri)
      return nil unless actor_data

      actor.assign_attributes(
        actor_type: actor_data["type"],
        inbox_url: actor_data["inbox"],
        shared_inbox_url: actor_data.dig("endpoints", "sharedInbox"),
        username: actor_data["preferredUsername"],
        domain: URI.parse(actor_uri).host,
        display_name: actor_data["name"],
        avatar_url: actor_data.dig("icon", "url"),
        public_key: actor_data.dig("publicKey", "publicKeyPem"),
        actor_data: actor_data,
        last_fetched_at: Time.current
      )
      actor.save!
    end

    actor
  rescue StandardError => e
    Rails.logger.error("[FederatedActor] Failed to fetch #{actor_uri}: #{e.message}")
    nil
  end

  def self.fetch_actor_document(actor_uri)
    uri = URI.parse(actor_uri)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      request["Accept"] = "application/activity+json, application/ld+json"
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("[FederatedActor] HTTP request failed for #{actor_uri}: #{e.message}")
    nil
  end
end
