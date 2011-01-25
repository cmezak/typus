# Configure Rails Envinronment

ENV["RAILS_ENV"] = "test"

# Boot rails application and testing parts ...
require File.expand_path('../../test/fixtures/rails_app/config/environment', __FILE__)
require "rails/test_help"
require "rspec/rails"
require File.expand_path('../../test/fixtures/rails_app/db/schema', __FILE__)
require File.expand_path('../../test/factories', __FILE__)
