class Post < ApplicationRecord
  belongs_to :webstead
  has_many :comments, dependent: :destroy
  # TODO: Uncomment when User model is created and migration adds user_id (step 4)
  # belongs_to :user, optional: true

  # Tenant isolation: scope all queries to current webstead
  default_scope -> { where(webstead_id: Current.webstead.id) if Current.webstead }

  # Auto-assign webstead from Current on creation
  before_validation :set_webstead_id, on: :create

  # Validations
  validates :title, presence: true, length: { minimum: 1, maximum: 300 }
  validates :webstead_id, presence: true
  validates :body, presence: true, if: :published?
  validate :published_posts_must_have_timestamp

  # Scopes
  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :draft, -> { where(published_at: nil) }
  scope :scheduled, -> { where("published_at > ?", Time.current) }
  scope :recent, -> { order(Arel.sql("published_at DESC NULLS LAST, created_at DESC")) }

  # Tenant isolation
  def self.for_webstead(webstead)
    where(webstead: webstead)
  end

  # Publication state methods
  def publish!(time = Time.current)
    update!(published_at: time)
  end

  def publish(time = Time.current)
    update(published_at: time)
  end

  def unpublish!
    update!(published_at: nil)
  end

  def published?
    published_at.present? && published_at <= Time.current
  end

  def draft?
    published_at.nil?
  end

  def scheduled?
    published_at.present? && published_at > Time.current
  end

  after_commit :enqueue_federation, on: [ :create, :update ], if: :should_federate?

  private

  def should_federate?
    saved_change_to_published_at? && published?
  end

  def enqueue_federation
    ActivityPub::FederatePostJob.perform_later(id) if defined?(ActivityPub::FederatePostJob)
  end

  def set_webstead_id
    self.webstead_id ||= Current.webstead&.id
  end

  def published_posts_must_have_timestamp
    if published_at.present? && published_at <= Time.current && body.blank?
      errors.add(:body, "can't be blank for published posts")
    end
  end
end
