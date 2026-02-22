# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :webstead

  def webstead_id
    webstead&.id
  end
end
