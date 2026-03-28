class Rack::Attack
  throttle("signups/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/websteads" && req.post?
  end

  # Rate limit ActivityPub inbox to prevent federation spam
  throttle("activitypub_inbox/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{/users/.+/inbox}) && req.post?
  end

  # Rate limit WebFinger lookups
  throttle("webfinger/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.path == "/.well-known/webfinger"
  end
end
