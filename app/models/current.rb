# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :webstead

  def webstead_id
    webstead&.id
  end
end
