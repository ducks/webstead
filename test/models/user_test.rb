require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user" do
    user = User.new(
      email: "test@example.com",
      username: "testuser",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
  end

  test "requires email" do
    user = User.new(username: "testuser", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires unique email" do
    User.create!(email: "test@example.com", username: "user1", password: "password123")
    user = User.new(email: "test@example.com", username: "user2", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "requires valid email format" do
    user = User.new(email: "invalid", username: "testuser", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "requires username" do
    user = User.new(email: "test@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "requires unique username" do
    User.create!(email: "user1@example.com", username: "testuser", password: "password123")
    user = User.new(email: "user2@example.com", username: "testuser", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "requires username between 3 and 30 characters" do
    user = User.new(email: "test@example.com", username: "ab", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "is too short (minimum is 3 characters)"

    user.username = "a" * 31
    assert_not user.valid?
    assert_includes user.errors[:username], "is too long (maximum is 30 characters)"
  end

  test "requires alphanumeric username with underscores" do
    user = User.new(email: "test@example.com", username: "test-user", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "only allows letters, numbers, and underscores"
  end

  test "requires password at least 8 characters" do
    user = User.new(email: "test@example.com", username: "testuser", password: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "normalizes email to lowercase" do
    user = User.create!(email: "TEST@EXAMPLE.COM", username: "testuser", password: "password123")
    assert_equal "test@example.com", user.email
  end

  test "normalizes username to lowercase" do
    user = User.create!(email: "test@example.com", username: "TestUser", password: "password123")
    assert_equal "testuser", user.username
  end

  test "authenticates with correct password" do
    user = User.create!(email: "test@example.com", username: "testuser", password: "password123")
    assert user.authenticate("password123")
  end

  test "does not authenticate with incorrect password" do
    user = User.create!(email: "test@example.com", username: "testuser", password: "password123")
    assert_not user.authenticate("wrongpassword")
  end

  test "display_name returns username" do
    user = User.new(username: "testuser")
    assert_equal "testuser", user.display_name
  end
end
