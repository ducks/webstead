class User < ApplicationRecord
  has_secure_password

  belongs_to :webstead, optional: true
  has_one :owned_webstead, class_name: "Webstead", foreign_key: "user_id"

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { in: 3..30 },
                       format: { with: /\A[a-zA-Z0-9_]+\z/, message: "only allows letters, numbers, and underscores" }

  validates :password, length: { minimum: 8 }, if: -> { new_record? || changes[:password_digest] }

  before_validation :normalize_attributes

  def display_name
    username
  end

  private

  def normalize_attributes
    self.email = email.downcase.strip if email.present?
    self.username = username.downcase.strip if username.present?
  end
end
