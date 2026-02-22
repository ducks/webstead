class Webstead < ApplicationRecord
  belongs_to :user

  # Reserved subdomains that cannot be registered
  RESERVED_SUBDOMAINS = %w[
    www api admin app dashboard blog forum mail email
    ftp ssh git status help support docs wiki assets
    cdn static media images uploads files download
    staging dev test development production
  ].freeze

  # Validations
  validates :subdomain, presence: true,
                        uniqueness: { case_sensitive: false },
                        length: { minimum: 3, maximum: 63 },
                        format: {
                          with: /\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/,
                          message: "must start and end with alphanumeric, contain only lowercase letters, numbers, and hyphens"
                        },
                        exclusion: {
                          in: RESERVED_SUBDOMAINS,
                          message: "is reserved"
                        }

  validates :custom_domain, uniqueness: { case_sensitive: false, allow_nil: true },
                            length: { maximum: 253, allow_nil: true },
                            format: {
                              with: /\A[a-z0-9][a-z0-9.-]*[a-z0-9]\z/,
                              message: "must be a valid domain name",
                              allow_nil: true
                            }

  validates :user_id, uniqueness: true

  # Settings accessor for jsonb column
  store_accessor :settings, :theme, :analytics_id, :custom_css

  # Helper methods
  def primary_domain
    custom_domain.presence || "#{subdomain}.webstead.dev"
  end

  def url
    "https://#{primary_domain}"
  end

  def to_param
    subdomain
  end

  # Normalize subdomain and custom_domain to lowercase before validation
  before_validation :normalize_domains

  private

  def normalize_domains
    self.subdomain = subdomain.downcase if subdomain.present?
    self.custom_domain = custom_domain.downcase if custom_domain.present?
  end
end
