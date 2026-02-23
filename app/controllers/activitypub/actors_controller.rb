module ActivityPub
  class ActorsController < ApplicationController
    def show
      webstead = Current.webstead

      if webstead.nil?
        render json: { error: "Webstead not found" }, status: :not_found
        return
      end

      serializer = ActorSerializer.new(webstead)

      render json: serializer.as_json,
             content_type: "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
    end
  end
end
