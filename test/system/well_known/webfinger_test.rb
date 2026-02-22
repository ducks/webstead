require "application_system_test_case"

module WellKnown
  class WebfingerTest < ApplicationSystemTestCase
    setup do
      @webstead = websteads(:alice)
      @host = "webstead.test"
    end

    test "webfinger endpoint returns valid JSON for existing user" do
      # Use Capybara to visit the WebFinger endpoint
      visit "http://#{@host}:#{Capybara.server_port}/.well-known/webfinger?resource=acct:#{@webstead.subdomain}@#{@host}"

      # Parse JSON response from page body
      json = JSON.parse(page.body)

      # Verify subject matches requested resource
      assert_equal "acct:#{@webstead.subdomain}@#{@host}", json["subject"]

      # Verify links array contains ActivityPub actor
      assert_equal 1, json["links"].length
      link = json["links"][0]

      assert_equal "self", link["rel"]
      assert_equal "application/activity+json", link["type"]

      # Verify actor href format
      expected_href = "http://#{@webstead.subdomain}.#{@host}/actor"
      assert_equal expected_href, link["href"]
    end

    test "webfinger returns 404 for non-existent user" do
      visit "http://#{@host}:#{Capybara.server_port}/.well-known/webfinger?resource=acct:nonexistent@#{@host}"

      json = JSON.parse(page.body)
      assert_equal "User not found", json["error"]
    end

    test "webfinger returns 404 for wrong domain" do
      visit "http://#{@host}:#{Capybara.server_port}/.well-known/webfinger?resource=acct:#{@webstead.subdomain}@other-domain.com"

      json = JSON.parse(page.body)
      assert_equal "Domain mismatch", json["error"]
    end

    test "webfinger returns 400 for malformed resource" do
      visit "http://#{@host}:#{Capybara.server_port}/.well-known/webfinger?resource=invalid-format"

      json = JSON.parse(page.body)
      assert_match(/Invalid resource format/, json["error"])
    end
  end
end
