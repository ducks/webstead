class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :webstead
  belongs_to :user, optional: true
  belongs_to :federated_actor, optional: true
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true

  scope :root_level, -> { where(parent_id: nil) }
  scope :recent, -> { order(created_at: :asc) }

  def actor_name
    user&.email || federated_actor&.username || "Anonymous"
  end
end
