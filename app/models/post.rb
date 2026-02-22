class Post < ApplicationRecord
  belongs_to :webstead
  # TODO: Uncomment when User model is created and migration adds user_id (step 4)
  # belongs_to :user, optional: true

  # Validations
  validates :title, presence: true, length: { minimum: 1, maximum: 300 }
  validates :body, presence: true, if: :published?
  validate :published_posts_must_have_timestamp

  # Scopes
  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :draft, -> { where(published_at: nil) }
  scope :scheduled, -> { where("published_at > ?", Time.current) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

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

  private

  def published_posts_must_have_timestamp
    if published_at.present? && published_at <= Time.current && body.blank?
      errors.add(:body, "can't be blank for published posts")
    end
  end
end
