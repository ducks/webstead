class Rack::Attack
  throttle("signups/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/websteads" && req.post?
  end
end
