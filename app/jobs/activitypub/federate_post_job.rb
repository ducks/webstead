# frozen_string_literal: true

require "kramdown"

module ActivityPub
  class FederatePostJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(post_id)
      post = Post.find_by(id: post_id)
      return unless post
      return if post.draft? || post.scheduled?

      webstead = post.webstead
      followers = webstead.followers.accepted.includes(:federated_actor)

      if followers.empty?
        Rails.logger.info("[FederatePostJob] No followers for post #{post_id}")
        return
      end

      activity = build_create_activity(post)
      inbox_urls = followers.map { |f| f.federated_actor.shared_inbox_url.presence || f.federated_actor.inbox_url }.uniq

      success_count = 0
      failure_count = 0

      inbox_urls.each do |inbox_url|
        begin
          deliver_to_inbox(inbox_url, activity, webstead)
          success_count += 1
        rescue StandardError => e
          Rails.logger.error("[FederatePostJob] Failed to deliver to #{inbox_url}: #{e.message}")
          failure_count += 1
        end
      end

      Rails.logger.info("[FederatePostJob] Post #{post_id}: #{success_count} succeeded, #{failure_count} failed")
    end

    private

    def build_create_activity(post)
      webstead = post.webstead
      actor_uri = webstead.actor_uri
      post_url = "#{webstead.url}/posts/#{post.id}"
      content_html = Kramdown::Document.new(post.body).to_html

      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": "#{post_url}/activity",
        "type": "Create",
        "actor": actor_uri,
        "published": post.published_at.iso8601,
        "to": [ "https://www.w3.org/ns/activitystreams#Public" ],
        "cc": [ "#{actor_uri}/followers" ],
        "object": {
          "id": post_url,
          "type": "Note",
          "published": post.published_at.iso8601,
          "attributedTo": actor_uri,
          "content": content_html,
          "to": [ "https://www.w3.org/ns/activitystreams#Public" ],
          "cc": [ "#{actor_uri}/followers" ],
          "url": post_url
        }
      }
    end

    def deliver_to_inbox(inbox_url, activity, webstead)
      uri = URI.parse(inbox_url)
      body = activity.to_json

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/activity+json"
      request["Accept"] = "application/activity+json"
      request.body = body

      ActivityPub::HttpSignatureService.sign_request(request, webstead, uri.host)

      response = http.request(request)

      unless response.code.to_i.between?(200, 299)
        raise "HTTP #{response.code}: #{response.body}"
      end

      Rails.logger.info("[FederatePostJob] Delivered to #{inbox_url}: HTTP #{response.code}")
    end
  end
end
