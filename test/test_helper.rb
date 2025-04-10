require "simplecov"
SimpleCov.start

if ENV["NO_RAILS"]
  puts "Running tests without Rails (ie not running the generator tests)"

  $LOAD_PATH.unshift File.expand_path("../lib", __dir__)
  require "typed_operation"

  require "minitest/autorun"

  # require "typed_operation"
  # require "type_fusion/minitest"
else
  puts "Running tests with Rails (ie also running the generator tests)"

  # Configure Rails Environment
  ENV["RAILS_ENV"] = "test"

  require_relative "../test/dummy/config/environment"
  ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
  require "rails/test_help"

  # Load fixtures from the engine
  if ActiveSupport::TestCase.respond_to?(:fixture_path=)
    ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
    ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
    ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
    ActiveSupport::TestCase.fixtures :all
  end
end
