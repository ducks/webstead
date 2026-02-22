# WebFinger controller for ActivityPub discovery
#
# Implements RFC 7033 WebFinger protocol to enable ActivityPub discovery.
# When a Mastodon user searches for @username@webstead.dev, Mastodon queries
# this endpoint to find the ActivityPub actor URI.
#
# Reference:
# - RFC 7033: https://datatracker.ietf.org/doc/html/rfc7033
# - ActivityPub spec section 4.2: https://www.w3.org/TR/activitypub/#actor-objects
#
# Expected query format:
#   GET /.well-known/webfinger?resource=acct:username@domain.com
#
# Example response:
#   {
#     "subject": "acct:alice@webstead.dev",
#     "links": [
#       {
#         "rel": "self",
#         "type": "application/activity+json",
#         "href": "https://alice.webstead.dev/actor"
#       }
#     ]
#   }
module WellKnown
  class WebfingerController < ApplicationController
    # WebFinger queries are always public, no authentication needed
    skip_before_action :verify_authenticity_token

    def show
      resource = params[:resource]

      # Validate resource parameter is present
      if resource.blank?
        render json: { error: "resource parameter is required" }, status: :bad_request
        return
      end

      # Parse username from acct: URI (format: acct:username@domain)
      match = resource.match(/^acct:([^@]+)@(.+)$/)
      unless match
        render json: { error: "Invalid resource format. Expected acct:username@domain" }, status: :bad_request
        return
      end

      username = match[1]
      domain = match[2]

      # Validate domain matches request host (reject queries for other domains)
      unless domain == request.host
        render json: { error: "Domain mismatch" }, status: :not_found
        return
      end

      # Look up webstead by subdomain (username)
      webstead = Webstead.find_by(subdomain: username)
      unless webstead
        render json: { error: "User not found" }, status: :not_found
        return
      end

      # Build WebFinger response conforming to RFC 7033
      webfinger_response = {
        subject: resource,
        links: [
          {
            rel: "self",
            type: "application/activity+json",
            href: actor_url(webstead)
          }
        ]
      }

      render json: webfinger_response, content_type: "application/jrd+json"
    end

    private

    def actor_url(webstead)
      protocol = Rails.env.production? ? "https" : "http"
      "#{protocol}://#{webstead.primary_domain}/actor"
    end
  end
end
