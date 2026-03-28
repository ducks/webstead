# frozen_string_literal: true

require "test_helper"

module ActivityPub
  class OutboxControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.create!(
        email: "outboxtest@example.com",
        username: "outboxuser",
        password: "password123",
        password_confirmation: "password123"
      )
      @webstead = Webstead.create!(user: @user, subdomain: "outboxtest")
      Current.webstead = @webstead

      @published_posts = 3.times.map do |i|
        Post.create!(
          title: "Published Post #{i + 1}",
          body: "Body of post #{i + 1} with **markdown**",
          webstead: @webstead,
          published_at: (3 - i).days.ago
        )
      end

      @draft_post = Post.create!(
        title: "Draft Post",
        body: nil,
        webstead: @webstead,
        published_at: nil
      )

      @scheduled_post = Post.create!(
        title: "Scheduled Post",
        body: "Future content",
        webstead: @webstead,
        published_at: 1.day.from_now
      )
    end

    teardown do
      Current.webstead = nil
    end

    def host_header
      { "Host" => "outboxtest.webstead.dev" }
    end

    def outbox_path
      "/@outboxuser/outbox"
    end

    # -- Collection summary (no page param) --

    test "returns OrderedCollection with totalItems and page URLs" do
      get outbox_path, headers: host_header

      assert_response :success
      assert_equal "application/activity+json", response.content_type

      json = JSON.parse(response.body)
      assert_equal "https://www.w3.org/ns/activitystreams", json["@context"]
      assert_equal "OrderedCollection", json["type"]
      assert_equal 3, json["totalItems"]
      assert_includes json["id"], "/@outboxtest/outbox"
      assert_includes json["first"], "page=1"
      assert_includes json["last"], "page=1"
    end

    test "collection does not include draft or scheduled posts in totalItems" do
      get outbox_path, headers: host_header

      json = JSON.parse(response.body)
      assert_equal 3, json["totalItems"]
    end

    # -- Paginated page --

    test "returns OrderedCollectionPage with Create activities" do
      get "#{outbox_path}?page=1", headers: host_header

      assert_response :success
      json = JSON.parse(response.body)

      assert_equal "OrderedCollectionPage", json["type"]
      assert_includes json["partOf"], "/@outboxtest/outbox"
      assert_equal 3, json["orderedItems"].length

      activity = json["orderedItems"].first
      assert_equal "Create", activity["type"]
      assert_includes activity["actor"], "/actor"
      assert_includes activity["to"], "https://www.w3.org/ns/activitystreams#Public"

      note = activity["object"]
      assert_equal "Note", note["type"]
      assert_includes note["content"], "<strong>markdown</strong>"
      assert_equal [], note["tag"]
    end

    test "posts are ordered by published_at DESC" do
      get "#{outbox_path}?page=1", headers: host_header

      json = JSON.parse(response.body)
      items = json["orderedItems"]
      dates = items.map { |i| i["published"] }

      assert_equal dates, dates.sort.reverse
    end

    test "pagination returns next/prev links when applicable" do
      # Create enough posts for 2 pages (need 31 total, already have 3)
      28.times do |i|
        Post.create!(
          title: "Extra Post #{i}",
          body: "Extra body #{i}",
          webstead: @webstead,
          published_at: (i + 10).days.ago
        )
      end

      get "#{outbox_path}?page=1", headers: host_header
      json = JSON.parse(response.body)

      assert_equal 30, json["orderedItems"].length
      assert_includes json["next"], "page=2"
      assert_nil json["prev"]

      get "#{outbox_path}?page=2", headers: host_header
      json = JSON.parse(response.body)

      assert_equal 1, json["orderedItems"].length
      assert_nil json["next"]
      assert_includes json["prev"], "page=1"
    end

    # -- Empty outbox --

    test "empty outbox returns collection with zero totalItems" do
      Post.where(webstead: @webstead).delete_all

      get outbox_path, headers: host_header

      json = JSON.parse(response.body)
      assert_equal 0, json["totalItems"]
      assert_equal "OrderedCollection", json["type"]
    end

    test "empty outbox page returns empty orderedItems" do
      Post.where(webstead: @webstead).delete_all

      get "#{outbox_path}?page=1", headers: host_header

      json = JSON.parse(response.body)
      assert_equal [], json["orderedItems"]
    end

    # -- 404 for unknown webstead --

    test "returns 404 for nonexistent webstead" do
      get "/@nonexistent/outbox", headers: { "Host" => "nonexistent.webstead.dev" }

      assert_response :not_found
    end

    # -- JSON-LD format --

    test "Create activity includes proper JSON-LD fields" do
      get "#{outbox_path}?page=1", headers: host_header

      json = JSON.parse(response.body)
      activity = json["orderedItems"].first

      assert_equal "https://www.w3.org/ns/activitystreams", activity["@context"]
      assert activity["id"].present?
      assert activity["published"].present?
      assert_includes activity["cc"].first, "/followers"
    end

    test "Note object includes required ActivityPub fields" do
      get "#{outbox_path}?page=1", headers: host_header

      json = JSON.parse(response.body)
      note = json["orderedItems"].first["object"]

      assert_equal "Note", note["type"]
      assert note["id"].present?
      assert note["attributedTo"].present?
      assert note["content"].present?
      assert note["published"].present?
      assert note["url"].present?
      assert_equal [], note["tag"]
    end
  end
end
