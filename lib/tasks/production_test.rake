# Rake tasks for validating production deployment.
# Run these after deploying to verify the stack is working.
#
# Usage:
#   bin/rails production:test:all         # Run all checks
#   bin/rails production:test:webfinger   # Test WebFinger endpoint
#   bin/rails production:test:actor       # Test ActivityPub actor
#   bin/rails production:test:isolation   # Test tenant isolation

namespace :production do
  namespace :test do
    desc "Run all production validation checks"
    task all: [ :webfinger, :actor, :isolation ]

    desc "Test WebFinger endpoint responds correctly"
    task webfinger: :environment do
      webstead = Webstead.first
      if !webstead
        puts "No websteads found. Create one first."
        exit 1
      end

      domain = webstead.primary_domain
      resource = "acct:#{webstead.subdomain}@webstead.dev"
      url = "https://#{domain}/.well-known/webfinger?resource=#{resource}"

      puts "Testing WebFinger: #{url}"
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      if response.code == "200"
        json = JSON.parse(response.body)
        puts "  Subject: #{json['subject']}"
        puts "  Links: #{json['links']&.length || 0}"
        puts "  PASS"
      else
        puts "  FAIL: HTTP #{response.code}"
        exit 1
      end
    end

    desc "Test ActivityPub actor endpoint"
    task actor: :environment do
      webstead = Webstead.first
      if !webstead
        puts "No websteads found. Create one first."
        exit 1
      end

      url = webstead.actor_uri
      puts "Testing Actor: #{url}"

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.path)
      request["Accept"] = "application/activity+json"
      response = http.request(request)

      if response.code == "200"
        json = JSON.parse(response.body)
        puts "  Type: #{json['type']}"
        puts "  Inbox: #{json['inbox']}"
        puts "  PublicKey: #{json.dig('publicKey', 'id')}"
        puts "  PASS"
      else
        puts "  FAIL: HTTP #{response.code}"
        exit 1
      end
    end

    desc "Test tenant isolation between websteads"
    task isolation: :environment do
      websteads = Webstead.limit(2).to_a
      if websteads.length < 2
        puts "Need at least 2 websteads to test isolation."
        puts "Create them first, then re-run."
        exit 1
      end

      w1, w2 = websteads

      # Create a test post in w1's context
      Current.webstead = w1
      post = w1.posts.create!(
        title: "Isolation test #{Time.current.to_i}",
        body: "This should only be visible in #{w1.subdomain}"
      )

      # Switch to w2's context and verify isolation
      Current.webstead = w2
      leaked = w2.posts.where(id: post.id).exists?

      if leaked
        puts "  FAIL: Post #{post.id} from #{w1.subdomain} visible in #{w2.subdomain}"
        post.destroy
        exit 1
      else
        puts "  Post #{post.id} correctly isolated to #{w1.subdomain}"
        puts "  PASS"
      end

      # Clean up
      Current.webstead = w1
      post.destroy
    ensure
      Current.reset
    end
  end
end
