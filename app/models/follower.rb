class Follower < ApplicationRecord
  include TenantScoped

  belongs_to :webstead

  validates :actor_uri, presence: true,
                        format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                                 message: "must be a valid HTTP(S) URL" },
                        uniqueness: { scope: :webstead_id,
                                     message: "is already following this webstead" }
  validates :inbox_url, presence: true,
                       format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :shared_inbox_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
                                        allow_blank: true }

  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :pending, -> { where(accepted_at: nil) }

  def accepted?
    accepted_at.present?
  end

  def pending?
    accepted_at.nil?
  end

  def accept!
    update!(accepted_at: Time.current)
  end
end
