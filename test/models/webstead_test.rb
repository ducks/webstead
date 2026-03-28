require "test_helper"

class WebsteadTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", username: "testuser", password: "password123", password_confirmation: "password123")
    @webstead = Webstead.new(user: @user, subdomain: "testuser")
  end

  test "valid webstead" do
    assert @webstead.valid?
  end

  test "subdomain is required" do
    @webstead.subdomain = nil
    assert_not @webstead.valid?
    assert_includes @webstead.errors[:subdomain], "can't be blank"
  end

  test "subdomain must be unique" do
    @webstead.save!
    duplicate = Webstead.new(user: User.create!(email: "other@example.com", username: "otheruser", password: "password123", password_confirmation: "password123"), subdomain: "testuser")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:subdomain], "has already been taken"
  end

  test "subdomain uniqueness is case insensitive" do
    @webstead.save!
    duplicate = Webstead.new(user: User.create!(email: "other@example.com", username: "otheruser", password: "password123", password_confirmation: "password123"), subdomain: "TESTUSER")
    assert_not duplicate.valid?
  end

  test "subdomain format validation" do
    invalid_subdomains = [
      "-startwithdash",
      "endwithdash-",
      "has space",
      "has_underscore",
      "special!char",
      "a",
      "ab"
    ]

    invalid_subdomains.each do |invalid|
      @webstead.subdomain = invalid
      assert_not @webstead.valid?, "#{invalid} should be invalid"
    end
  end

  test "subdomain length constraints" do
    @webstead.subdomain = "ab"
    assert_not @webstead.valid?

    @webstead.subdomain = "a" * 64
    assert_not @webstead.valid?

    @webstead.subdomain = "a" * 63
    assert @webstead.valid?
  end

  test "reserved subdomains are rejected" do
    Webstead::RESERVED_SUBDOMAINS.each do |reserved|
      @webstead.subdomain = reserved
      assert_not @webstead.valid?, "#{reserved} should be reserved"
      assert_includes @webstead.errors[:subdomain], "is reserved"
    end
  end

  test "custom domain validation" do
    @webstead.custom_domain = "example.com"
    assert @webstead.valid?

    @webstead.custom_domain = "sub.example.com"
    assert @webstead.valid?

    @webstead.custom_domain = "invalid domain"
    assert_not @webstead.valid?
  end

  test "custom domain uniqueness" do
    @webstead.custom_domain = "example.com"
    @webstead.save!

    duplicate = Webstead.new(
      user: User.create!(email: "other@example.com", username: "otheruser", password: "password123", password_confirmation: "password123"),
      subdomain: "other",
      custom_domain: "example.com"
    )
    assert_not duplicate.valid?
  end

  test "user can only have one webstead" do
    @webstead.save!
    duplicate = Webstead.new(user: @user, subdomain: "another")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "settings accessor" do
    @webstead.theme = "dark"
    @webstead.analytics_id = "UA-12345"
    @webstead.custom_css = "body { color: red; }"
    @webstead.save!

    reloaded = Webstead.find(@webstead.id)
    assert_equal "dark", reloaded.theme
    assert_equal "UA-12345", reloaded.analytics_id
    assert_equal "body { color: red; }", reloaded.custom_css
  end

  test "primary_domain returns custom domain if set" do
    @webstead.custom_domain = "example.com"
    assert_equal "example.com", @webstead.primary_domain
  end

  test "primary_domain returns subdomain if no custom domain" do
    assert_equal "testuser.webstead.dev", @webstead.primary_domain
  end

  test "url returns https URL" do
    assert_equal "https://testuser.webstead.dev", @webstead.url

    @webstead.custom_domain = "example.com"
    assert_equal "https://example.com", @webstead.url
  end

  test "to_param returns subdomain" do
    assert_equal "testuser", @webstead.to_param
  end

  test "subdomain is normalized to lowercase" do
    @webstead.subdomain = "TestUser"
    @webstead.valid?
    assert_equal "testuser", @webstead.subdomain
  end

  test "custom_domain is normalized to lowercase" do
    @webstead.custom_domain = "Example.COM"
    @webstead.valid?
    assert_equal "example.com", @webstead.custom_domain
  end

  test "uppercase subdomain is normalized and valid" do
    @webstead.subdomain = "MYWEBSTEAD"
    assert @webstead.valid?
    assert_equal "mywebstead", @webstead.subdomain
  end

  test "generates keypair after creation" do
    @webstead.save!
    assert @webstead.private_key_pem.present?, "private_key_pem should be generated"
    assert @webstead.public_key_pem.present?, "public_key_pem should be generated"
  end

  test "generated keypair is valid RSA" do
    @webstead.save!
    private_key = OpenSSL::PKey::RSA.new(@webstead.private_key_pem)
    public_key = OpenSSL::PKey::RSA.new(@webstead.public_key_pem)

    assert private_key.private?
    assert_not public_key.private?
  end

  test "rotated_at is set after keypair generation" do
    @webstead.save!
    assert @webstead.rotated_at.present?
  end

  test "rotate_keypair! generates new keypair" do
    @webstead.save!
    old_public_key = @webstead.public_key_pem

    @webstead.rotate_keypair!
    assert_not_equal old_public_key, @webstead.public_key_pem
  end

  test "actor_uri returns correct URI" do
    assert_equal "https://testuser.webstead.dev/actor", @webstead.actor_uri
  end

  test "actor_public_key_id returns correct ID" do
    assert_equal "https://testuser.webstead.dev/actor#main-key", @webstead.actor_public_key_id
  end

  test "private_key_object returns OpenSSL key" do
    @webstead.save!
    key = @webstead.private_key_object
    assert_instance_of OpenSSL::PKey::RSA, key
    assert key.private?
  end

  test "public_key_object returns OpenSSL key" do
    @webstead.save!
    key = @webstead.public_key_object
    assert_instance_of OpenSSL::PKey::RSA, key
  end
end
