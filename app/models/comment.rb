class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :webstead
  belongs_to :user
  belongs_to :federated_actor
end
