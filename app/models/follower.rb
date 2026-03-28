class Follower < ApplicationRecord
  belongs_to :webstead

  # Tenant isolation: scope all queries to current webstead
  default_scope -> { where(webstead_id: Current.webstead.id) if Current.webstead }

  # Auto-assign webstead from Current on creation
  before_validation :set_webstead_id, on: :create

  validates :actor_uri, presence: true,
                        format: { with: /\Ahttps?:\/\/.+/,
                                  message: "must be a valid HTTP(S) URL" },
                        uniqueness: { scope: :webstead_id,
                                      message: "is already following this webstead" }
  validates :inbox_url, presence: true,
                        format: { with: /\Ahttps?:\/\/.+/,
                                  message: "must be a valid HTTP(S) URL" }
  validates :shared_inbox_url, format: { with: /\Ahttps?:\/\/.+/,
                                         message: "must be a valid HTTP(S) URL",
                                         allow_blank: true }
  validates :webstead_id, presence: true

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

  private

  def set_webstead_id
    self.webstead_id ||= Current.webstead&.id
  end
end
