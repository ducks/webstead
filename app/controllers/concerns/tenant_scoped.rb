# frozen_string_literal: true

module TenantScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_current_webstead
  end

  private

  def set_current_webstead
    subdomain = request.host.split('.').first
    Current.webstead = Webstead.find_by!(subdomain: subdomain)
  rescue ActiveRecord::RecordNotFound
    render plain: "Webstead not found", status: :not_found
  end
end
