class SetCurrentWebstead
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    subdomain = extract_subdomain(request.host)

    if subdomain.present? && !reserved_subdomain?(subdomain)
      webstead = Webstead.find_by(subdomain: subdomain)
      
      if webstead
        Current.webstead = webstead
      else
        Rails.logger.info "Subdomain not found: #{subdomain} from host: #{request.host}"
        return render_404(env)
      end
    end

    @app.call(env)
  ensure
    Current.reset
  end

  private

  def extract_subdomain(host)
    host = host.split(':').first
    
    parts = host.split('.')
    return nil if parts.length < 3
    
    parts.first
  end

  def reserved_subdomain?(subdomain)
    %w[www api admin].include?(subdomain)
  end

  def render_404(env)
    [
      404,
      { 'Content-Type' => 'text/html' },
      [File.read(Rails.root.join('public', '404.html'))]
    ]
  end
end