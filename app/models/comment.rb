class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :webstead
  belongs_to :user, optional: true
  belongs_to :federated_actor, optional: true
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  # Tenant isolation: scope all queries to current webstead
  default_scope -> { where(webstead_id: Current.webstead.id) if Current.webstead }

  # Auto-assign webstead from Current on creation
  before_validation :set_webstead_id, on: :create

  validates :body, presence: true, length: { minimum: 1, maximum: 10_000 }
  validates :webstead_id, presence: true
  validates :post_id, presence: true
  validate :has_exactly_one_author

  scope :root_comments, -> { where(parent_id: nil) }
  scope :chronological, -> { order(created_at: :asc) }

  def author_name
    user&.display_name || federated_actor&.display_name || federated_actor&.username || "Anonymous"
  end

  def author_url
    if user.present?
      user
    elsif federated_actor.present?
      federated_actor.actor_uri
    end
  end

  def root?
    parent_id.nil?
  end

  def depth
    count = 0
    current = self
    while current.parent_id.present?
      count += 1
      current = current.parent
    end
    count
  end

  private

  def has_exactly_one_author
    if user_id.present? && federated_actor_id.present?
      errors.add(:base, "Comment cannot have both user_id and federated_actor_id")
    elsif user_id.blank? && federated_actor_id.blank?
      errors.add(:base, "Comment must have either user_id or federated_actor_id")
    end
  end

  def set_webstead_id
    self.webstead_id ||= Current.webstead&.id
  end
end
