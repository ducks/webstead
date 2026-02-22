class Comment < ApplicationRecord
  belongs_to :webstead
  belongs_to :post
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :content, presence: true
  validates :author_name, presence: true
  validates :webstead_id, presence: true

  before_create :set_webstead_id

  default_scope { where(webstead_id: Current.webstead&.id) if Current.webstead }

  private

  def set_webstead_id
    self.webstead_id ||= Current.webstead&.id
  end
end