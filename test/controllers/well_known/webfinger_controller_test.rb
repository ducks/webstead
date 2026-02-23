require "test_helper"

module WellKnown
  class WebfingerControllerTest < ActionDispatch::IntegrationTest
    setup do
      @webstead = websteads(:alice)
      @host = "webstead.test"
    end

    test "should return webfinger response for valid user" do
      get well_known_webfinger_url,
          params: { resource: "acct:#{@webstead.subdomain}@#{@host}" },
          headers: { "Host" => @host }

      assert_response :success
      assert_equal "application/jrd+json", response.content_type

      json = JSON.parse(response.body)
      assert_equal "acct:#{@webstead.subdomain}@#{@host}", json["subject"]
      assert_equal 1, json["links"].length

      link = json["links"][0]
      assert_equal "self", link["rel"]
      assert_equal "application/activity+json", link["type"]
      assert_equal "http://#{@webstead.subdomain}.#{@host}/actor", link["href"]
    end

    test "should return 404 for non-existent user" do
      get well_known_webfinger_url,
          params: { resource: "acct:nonexistent@#{@host}" },
          headers: { "Host" => @host }

      assert_response :not_found
      json = JSON.parse(response.body)
      assert_equal "User not found", json["error"]
    end

    test "should return 404 for domain mismatch" do
      get well_known_webfinger_url,
          params: { resource: "acct:#{@webstead.subdomain}@other-domain.com" },
          headers: { "Host" => @host }

      assert_response :not_found
      json = JSON.parse(response.body)
      assert_equal "Domain mismatch", json["error"]
    end

    test "should return 400 for missing resource parameter" do
      get well_known_webfinger_url, headers: { "Host" => @host }

      assert_response :bad_request
      json = JSON.parse(response.body)
      assert_equal "resource parameter is required", json["error"]
    end

    test "should return 400 for malformed resource parameter" do
      get well_known_webfinger_url,
          params: { resource: "invalid-format" },
          headers: { "Host" => @host }

      assert_response :bad_request
      json = JSON.parse(response.body)
      assert_match(/Invalid resource format/, json["error"])
    end

    test "should return 400 for resource without domain" do
      get well_known_webfinger_url,
          params: { resource: "acct:alice" },
          headers: { "Host" => @host }

      assert_response :bad_request
      json = JSON.parse(response.body)
      assert_match(/Invalid resource format/, json["error"])
    end

    test "actor URL should use https in production" do
      Rails.stub :env, ActiveSupport::EnvironmentInquirer.new("production") do
        get well_known_webfinger_url,
            params: { resource: "acct:#{@webstead.subdomain}@#{@host}" },
            headers: { "Host" => @host }

        assert_response :success
        json = JSON.parse(response.body)
        assert_match(/^https:\/\//, json["links"][0]["href"])
      end
    end
  end
end
