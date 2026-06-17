class SetCurrentWebstead
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    host = request.host.split(":").first
    if platform_subdomain?(host)
      subdomain = host.split(".").first

      unless reserved_subdomain?(subdomain)
        webstead = Webstead.find_by(subdomain: subdomain)
        if webstead
          Current.webstead = webstead
        else
          Rails.logger.info "Webstead not found for subdomain: #{subdomain} (host: #{host})"
          return render_not_found
        end
      end
    elsif !platform_domain?(host)
      # Not the platform domain -> might be a webstead's custom domain. Resolve
      # by EXACT custom_domain match (never by subdomain — a custom domain whose
      # first label happens to equal a webstead's subdomain must not collide).
      # If no webstead claims this host, pass through untouched: it's an
      # ordinary request (the bare app, auth pages, the test host, etc.), not a
      # missing webstead. Only an unknown *platform subdomain* is a 404.
      webstead = Webstead.find_by(custom_domain: host)
      Current.webstead = webstead if webstead
    end

    @app.call(env)
  ensure
    Current.reset
  end

  private

  def platform_domain
    Rails.application.config.x.webstead_domain
  end

  # Bare platform domain, e.g. "webstead.test" (no tenant subdomain).
  def platform_domain?(host)
    host == platform_domain
  end

  # A tenant subdomain of the platform domain, e.g. "alice.webstead.test".
  def platform_subdomain?(host)
    host.end_with?(".#{platform_domain}")
  end

  def reserved_subdomain?(subdomain)
    %w[www api admin].include?(subdomain)
  end

  def render_not_found
    body = File.read(
      Rails.root.join("app", "views", "errors", "webstead_not_found.html.erb")
    )
    [ 404, { "content-type" => "text/html; charset=utf-8" }, [ body ] ]
  end
end
