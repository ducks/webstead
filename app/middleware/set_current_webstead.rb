class SetCurrentWebstead
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    subdomain = extract_subdomain(request.host)

    if subdomain.present? && !reserved_subdomain?(subdomain)
      webstead = find_webstead(subdomain, request.host)

      if webstead
        Current.webstead = webstead
      else
        Rails.logger.info "Webstead not found for subdomain: #{subdomain} (host: #{request.host})"
        return render_not_found
      end
    end

    @app.call(env)
  ensure
    Current.reset
  end

  private

  def extract_subdomain(host)
    host = host.split(":").first
    parts = host.split(".")
    return nil if parts.length < 3

    parts.first
  end

  def find_webstead(subdomain, host)
    host_without_port = host.split(":").first
    Webstead.find_by(subdomain: subdomain) ||
      Webstead.find_by(custom_domain: host_without_port)
  end

  def reserved_subdomain?(subdomain)
    %w[www api admin].include?(subdomain)
  end

  def render_not_found
    body = File.read(
      Rails.root.join("app", "views", "errors", "webstead_not_found.html.erb")
    )
    [404, { "content-type" => "text/html; charset=utf-8" }, [body]]
  end
end
