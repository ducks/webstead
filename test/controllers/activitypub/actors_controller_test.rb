require "test_helper"

module ActivityPub
  class ActorsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @webstead = Webstead.create!(subdomain: "actortest")
      @webstead.settings["display_name"] = "Actor Test"
      @webstead.settings["bio"] = "This is a test actor"
      @webstead.save!

      # Set Current.webstead for tenant scoping
      Current.webstead = @webstead
    end

    test "should return actor document" do
      get "/actor", headers: { "Host" => "actortest.webstead.dev" }

      assert_response :success
      assert_equal "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"", response.content_type

      json = JSON.parse(response.body)
      assert_equal "Person", json["type"]
      assert_equal "https://actortest.webstead.dev/actor", json["id"]
      assert_equal "actortest", json["preferredUsername"]
      assert_equal "Actor Test", json["name"]
      assert_equal "This is a test actor", json["summary"]
      assert_equal "https://actortest.webstead.dev", json["url"]
      assert_equal "https://actortest.webstead.dev/actor/inbox", json["inbox"]
      assert_equal "https://actortest.webstead.dev/actor/outbox", json["outbox"]
    end

    test "should include publicKey in actor document" do
      get "/actor", headers: { "Host" => "actortest.webstead.dev" }

      assert_response :success

      json = JSON.parse(response.body)
      assert_not_nil json["publicKey"]
      assert_equal "https://actortest.webstead.dev/actor#main-key", json["publicKey"]["id"]
      assert_equal "https://actortest.webstead.dev/actor", json["publicKey"]["owner"]
      assert_match(/BEGIN PUBLIC KEY/, json["publicKey"]["publicKeyPem"])
    end

    test "should use subdomain as name if display_name not set" do
      @webstead.settings.delete("display_name")
      @webstead.save!

      get "/actor", headers: { "Host" => "actortest.webstead.dev" }

      assert_response :success

      json = JSON.parse(response.body)
      assert_equal "actortest", json["name"]
    end

    test "should return 404 if webstead not found" do
      Current.webstead = nil

      get "/actor", headers: { "Host" => "nonexistent.webstead.dev" }

      assert_response :not_found
      json = JSON.parse(response.body)
      assert_equal "Webstead not found", json["error"]
    end
  end
end
