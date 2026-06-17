ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Platform base domain for the current env (webstead.test in test).
    # Derive from config — never hardcode the domain in individual tests.
    def platform_domain
      Rails.application.config.x.webstead_domain
    end
  end
end
