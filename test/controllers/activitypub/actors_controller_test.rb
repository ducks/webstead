require "test_helper"

module ActivityPub
  class ActorsControllerTest < ActionDispatch::IntegrationTest
    self.use_transactional_tests = false
    parallelize(workers: 1)

    setup do
      suffix = SecureRandom.hex(4)
      @user = User.create!(
        email: "actor_#{suffix}@example.com",
        username: "actor_#{suffix}",
        password: "password123",
        password_confirmation: "password123"
      )
      @webstead = Webstead.create!(user: @user, subdomain: "actortest#{suffix}")
      @webstead.settings["display_name"] = "Actor Test"
      @webstead.settings["bio"] = "This is a test actor"
      @webstead.save!

      # Set Current.webstead for tenant scoping
      Current.webstead = @webstead
    end

    teardown do
      @webstead&.destroy
      @user&.destroy
    end

    test "should return actor document" do
      get "/actor", headers: { "Host" => "#{@webstead.subdomain}.webstead.test" }

      assert_response :success
      assert_includes response.content_type, "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""

      json = JSON.parse(response.body)
      assert_equal "Person", json["type"]
      assert_equal "https://#{@webstead.subdomain}.webstead.test/actor", json["id"]
      assert_equal @webstead.subdomain, json["preferredUsername"]
      assert_equal "Actor Test", json["name"]
      assert_equal "This is a test actor", json["summary"]
      assert_equal "https://#{@webstead.subdomain}.webstead.test", json["url"]
      assert_equal "https://#{@webstead.subdomain}.webstead.test/actor/inbox", json["inbox"]
      assert_equal "https://#{@webstead.subdomain}.webstead.test/actor/outbox", json["outbox"]
    end

    test "should include publicKey in actor document" do
      get "/actor", headers: { "Host" => "#{@webstead.subdomain}.webstead.test" }

      assert_response :success

      json = JSON.parse(response.body)
      assert_not_nil json["publicKey"]
      assert_equal "https://#{@webstead.subdomain}.webstead.test/actor#main-key", json["publicKey"]["id"]
      assert_equal "https://#{@webstead.subdomain}.webstead.test/actor", json["publicKey"]["owner"]
      assert_match(/BEGIN PUBLIC KEY/, json["publicKey"]["publicKeyPem"])
    end

    test "should use subdomain as name if display_name not set" do
      @webstead.settings.delete("display_name")
      @webstead.save!

      get "/actor", headers: { "Host" => "#{@webstead.subdomain}.webstead.test" }

      assert_response :success

      json = JSON.parse(response.body)
      assert_equal @webstead.subdomain, json["name"]
    end

    test "should return 404 if webstead not found" do
      Current.webstead = nil

      get "/actor", headers: { "Host" => "nonexistent.webstead.test" }

      assert_response :not_found
    end
  end
end
