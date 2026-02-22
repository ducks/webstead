class Post < ApplicationRecord
  belongs_to :webstead
  has_many :comments, dependent: :destroy

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: :webstead_id }
  validates :content, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft published] }
  validates :webstead_id, presence: true

  before_validation :generate_slug, on: :create
  before_create :set_webstead_id

  default_scope { where(webstead_id: Current.webstead&.id) if Current.webstead }

  private

  def generate_slug
    self.slug ||= title.parameterize if title.present?
  end

  def set_webstead_id
    self.webstead_id ||= Current.webstead&.id
  end
end