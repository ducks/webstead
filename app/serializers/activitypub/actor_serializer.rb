module ActivityPub
  class ActorSerializer
    def initialize(webstead)
      @webstead = webstead
    end

    def as_json
      {
        "@context": [
          "https://www.w3.org/ns/activitystreams",
          "https://w3id.org/security/v1"
        ],
        type: "Person",
        id: @webstead.actor_uri,
        preferredUsername: @webstead.subdomain,
        name: @webstead.settings["display_name"] || @webstead.subdomain,
        summary: @webstead.settings["bio"],
        url: @webstead.url,
        inbox: "#{@webstead.actor_uri}/inbox",
        outbox: "#{@webstead.actor_uri}/outbox",
        publicKey: {
          id: "#{@webstead.actor_uri}#main-key",
          owner: @webstead.actor_uri,
          publicKeyPem: @webstead.public_key_pem
        }
      }.compact
    end
  end
end
