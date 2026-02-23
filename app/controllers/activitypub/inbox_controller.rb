# frozen_string_literal: true

module ActivityPub
  class InboxController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_signature
    before_action :parse_activity
    before_action :load_webstead

    def create
      case @activity["type"]
      when "Follow"
        handle_follow
      else
        render json: { error: "Activity type not supported in v1" }, status: :not_implemented
      end
    end

    private

    def verify_signature
      # Skip verification in test/development if env var set (never in production)
      if ENV["SKIP_SIGNATURE_VERIFICATION"] == "true" && !Rails.env.production?
        Rails.logger.warn("[ActivityPub] Skipping signature verification (development mode)")
        return
      end

      signature_header = request.headers["Signature"]
      return render json: { error: "Missing Signature header" }, status: :bad_request if signature_header.blank?

      signature_params = parse_signature_header(signature_header)
      return render json: { error: "Malformed Signature header" }, status: :bad_request unless signature_params

      actor_uri = signature_params[:key_id]
      actor_document = fetch_actor_document(actor_uri)
      return render json: { error: "Failed to fetch actor" }, status: :service_unavailable unless actor_document

      public_key_pem = actor_document.dig("publicKey", "publicKeyPem")
      return render json: { error: "No public key in actor document" }, status: :bad_request unless public_key_pem

      signing_string = build_signing_string(signature_params[:headers])
      signature_valid = verify_rsa_signature(public_key_pem, signature_params[:signature], signing_string)

      render json: { error: "Invalid signature" }, status: :unauthorized unless signature_valid
    rescue StandardError => e
      Rails.logger.error("[ActivityPub] Signature verification failed: #{e.message}")
      render json: { error: "Signature verification error" }, status: :unauthorized
    end

    def parse_signature_header(header)
      params = {}
      header.scan(/(\w+)="([^"]*)"/).each do |key, value|
        params[key.to_sym] = value
      end

      return nil unless params[:keyId] && params[:signature] && params[:headers]

      {
        key_id: params[:keyId],
        signature: Base64.strict_decode64(params[:signature]),
        headers: params[:headers].split
      }
    rescue StandardError
      nil
    end

    def build_signing_string(headers_list)
      headers_list.map do |header|
        case header
        when "(request-target)"
          "(request-target): post #{request.fullpath}"
        when "host"
          "host: #{request.host}"
        when "date"
          "date: #{request.headers['Date']}"
        when "digest"
          "digest: #{request.headers['Digest']}"
        else
          "#{header}: #{request.headers[header.capitalize]}"
        end
      end.join("\n")
    end

    def verify_rsa_signature(public_key_pem, signature, signing_string)
      public_key = OpenSSL::PKey::RSA.new(public_key_pem)
      public_key.verify(OpenSSL::Digest::SHA256.new, signature, signing_string)
    rescue StandardError => e
      Rails.logger.error("[ActivityPub] RSA verification failed: #{e.message}")
      false
    end

    def fetch_actor_document(actor_uri)
      cache_key = "activitypub:actor:#{Digest::SHA256.hexdigest(actor_uri)}"
      Rails.cache.fetch(cache_key, expires_in: 24.hours) do
        uri = URI.parse(actor_uri)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request["Accept"] = "application/activity+json, application/ld+json"
          http.request(request)
        end

        return nil unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    rescue StandardError => e
      Rails.logger.error("[ActivityPub] Failed to fetch actor #{actor_uri}: #{e.message}")
      nil
    end

    def parse_activity
      @activity = JSON.parse(request.body.read)
      required_fields = [ "@context", "type", "actor" ]
      missing_fields = required_fields - @activity.keys

      if missing_fields.any?
        render json: { error: "Missing required fields: #{missing_fields.join(', ')}" }, status: :bad_request
      end
    rescue JSON::ParserError => e
      Rails.logger.error("[ActivityPub] JSON parse error: #{e.message}")
      render json: { error: "Invalid JSON" }, status: :bad_request
    end

    def load_webstead
      username = params[:username]
      user = User.find_by(username: username)
      return render json: { error: "User not found" }, status: :not_found unless user

      @webstead = user.webstead
      return render json: { error: "Webstead not found" }, status: :not_found unless @webstead

      @user = user
    end

    def handle_follow
      actor_uri = @activity["actor"]
      object_uri = @activity["object"]
      expected_uri = "https://#{@webstead.primary_domain}/users/#{@user.username}"

      if object_uri != expected_uri
        return render json: { error: "Object URI does not match user" }, status: :bad_request
      end

      # Fetch full actor document
      actor_document = fetch_actor_document(actor_uri)
      return render json: { error: "Failed to fetch follower actor" }, status: :service_unavailable unless actor_document

      # Find or create federated actor
      federated_actor = FederatedActor.find_or_create_by!(actor_uri: actor_uri) do |actor|
        actor.actor_type = actor_document["type"]
        actor.inbox_url = actor_document["inbox"]
        actor.shared_inbox_url = actor_document.dig("endpoints", "sharedInbox")
        actor.username = actor_document["preferredUsername"]
        actor.domain = URI.parse(actor_uri).host
        actor.public_key = actor_document.dig("publicKey", "publicKeyPem")
        actor.actor_data = actor_document
      end

      # Find or create follower (idempotent)
      follower = Follower.find_or_create_by!(
        webstead: @webstead,
        federated_actor: federated_actor
      ) do |f|
        f.status = "accepted"
      end

      # Generate and deliver Accept activity
      accept_activity = build_accept_activity
      inbox_url = federated_actor.shared_inbox_url || federated_actor.inbox_url

      ActivityPub::DeliveryJob.perform_later(
        activity: accept_activity,
        inbox_url: inbox_url,
        signing_key: @webstead.private_key,
        signing_key_id: "https://#{@webstead.primary_domain}/users/#{@user.username}#main-key"
      )

      Rails.logger.info("[ActivityPub] Follow accepted from #{actor_uri} for #{@user.username}")
      head :accepted
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[ActivityPub] Failed to create follower: #{e.message}")
      render json: { error: "Failed to process follow" }, status: :unprocessable_entity
    end

    def build_accept_activity
      {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Accept",
        "id" => "https://#{@webstead.primary_domain}/activities/#{SecureRandom.uuid}",
        "actor" => "https://#{@webstead.primary_domain}/users/#{@user.username}",
        "object" => @activity
      }
    end
  end
end
