module ActivityPub
  class ActorsController < ApplicationController
    include TenantScoped

    def show
      serializer = ActorSerializer.new(Current.webstead)

      render json: serializer.as_json,
             content_type: "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
    end
  end
end
