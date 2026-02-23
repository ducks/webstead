class Follower < ApplicationRecord
  include TenantScoped

  belongs_to :webstead
  belongs_to :federated_actor

  validates :federated_actor_id, presence: true,
                                 uniqueness: { scope: :webstead_id,
                                              message: "is already following this webstead" }
  validates :status, presence: true,
                     inclusion: { in: %w[pending accepted rejected] }

  scope :accepted, -> { where(status: "accepted") }
  scope :pending, -> { where(status: "pending") }
  scope :rejected, -> { where(status: "rejected") }

  def accepted?
    status == "accepted"
  end

  def pending?
    status == "pending"
  end

  def rejected?
    status == "rejected"
  end

  def accept!
    update!(status: "accepted", accepted_at: Time.current)
  end

  def reject!
    update!(status: "rejected")
  end
end
