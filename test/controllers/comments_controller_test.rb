require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "commenter@example.com",
      username: "commenter",
      password: "password123",
      password_confirmation: "password123"
    )
    @webstead = Webstead.create!(user: @user, subdomain: "commentblog")
    Current.webstead = @webstead
    @post = Post.create!(
      webstead: @webstead,
      title: "Test Post",
      body: "Some content here",
      published_at: 1.hour.ago
    )

    # Sign in
    post login_url, params: { email: @user.email, password: "password123" }
  end

  teardown do
    Current.webstead = nil
  end

  def host_header
    { "Host" => "commentblog.webstead.test" }
  end

  # -- Creating top-level comments --

  test "create top-level comment via turbo stream" do
    assert_difference "Comment.count", 1 do
      post comments_url, headers: host_header.merge("Accept" => "text/vnd.turbo-stream.html"), params: {
        comment: {
          body: "Great post!",
          parent_type: "Post",
          parent_id: @post.id
        }
      }
    end

    assert_response :success
    assert_match "turbo-stream", response.content_type

    comment = Comment.last
    assert_equal "Great post!", comment.body
    assert_equal @post, comment.post
    assert_equal @user, comment.user
    assert_equal @webstead, comment.webstead
    assert_nil comment.parent_id
  end

  test "create top-level comment via html fallback" do
    assert_difference "Comment.count", 1 do
      post comments_url, headers: host_header, params: {
        comment: {
          body: "Nice article",
          parent_type: "Post",
          parent_id: @post.id
        }
      }
    end

    assert_response :redirect
    comment = Comment.last
    assert_equal "Nice article", comment.body
    assert_nil comment.parent_id
  end

  # -- Creating nested replies --

  test "create nested reply to existing comment" do
    parent_comment = Comment.create!(
      body: "Parent comment",
      post: @post,
      webstead: @webstead,
      user: @user
    )

    assert_difference "Comment.count", 1 do
      post comments_url, headers: host_header.merge("Accept" => "text/vnd.turbo-stream.html"), params: {
        comment: {
          body: "This is a reply",
          parent_type: "Comment",
          parent_id: parent_comment.id
        }
      }
    end

    assert_response :success

    reply = Comment.last
    assert_equal "This is a reply", reply.body
    assert_equal parent_comment, reply.parent
    assert_equal @post, reply.post
  end

  # -- Validation errors --

  test "invalid comment returns unprocessable via turbo stream" do
    assert_no_difference "Comment.count" do
      post comments_url, headers: host_header.merge("Accept" => "text/vnd.turbo-stream.html"), params: {
        comment: {
          body: "",
          parent_type: "Post",
          parent_id: @post.id
        }
      }
    end

    assert_response :success
    assert_match "turbo-stream", response.content_type
  end

  test "invalid comment via html redirects back" do
    assert_no_difference "Comment.count" do
      post comments_url, headers: host_header.merge("HTTP_REFERER" => post_url(@post, host: "commentblog.webstead.test")), params: {
        comment: {
          body: "",
          parent_type: "Post",
          parent_id: @post.id
        }
      }
    end

    assert_response :redirect
  end

  # -- Authentication --

  test "unauthenticated user cannot create comment" do
    delete logout_url
    assert_no_difference "Comment.count" do
      post comments_url, headers: host_header, params: {
        comment: {
          body: "Should not work",
          parent_type: "Post",
          parent_id: @post.id
        }
      }
    end

    assert_response :redirect
  end

  # -- Tenant isolation --

  test "cannot comment on post from different webstead" do
    other_user = User.create!(
      email: "other@example.com",
      username: "other",
      password: "password123",
      password_confirmation: "password123"
    )
    other_webstead = Webstead.create!(user: other_user, subdomain: "otherblog")
    Current.webstead = other_webstead
    other_post = Post.create!(
      webstead: other_webstead,
      title: "Other Post",
      body: "Other content",
      published_at: 1.hour.ago
    )
    Current.webstead = @webstead

    assert_no_difference "Comment.count" do
      post comments_url, headers: host_header, params: {
        comment: {
          body: "Cross-tenant attack",
          parent_type: "Post",
          parent_id: other_post.id
        }
      }
    end

    # Post from another webstead is not found due to tenant scoping
    assert_response :not_found
  end

  # -- Turbo Stream response content --

  test "successful turbo stream appends comment and resets form" do
    post comments_url, headers: host_header.merge("Accept" => "text/vnd.turbo-stream.html"), params: {
      comment: {
        body: "Turbo test comment",
        parent_type: "Post",
        parent_id: @post.id
      }
    }

    assert_response :success
    # Turbo Stream should contain append and replace actions
    assert_match "turbo-stream", response.body
    assert_match "Turbo test comment", response.body
  end
end
