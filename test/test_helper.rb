# Configure SimpleCov if COVERAGE is set
if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov_small_badge"

  SimpleCov.start do
    add_filter "/test/"
    enable_coverage :branch

    # Define groups for the coverage report
    add_group "Core", "lib/typed_operation"
    add_group "Rails", "lib/typed_operation/rails"

    # Configure formatters - HTML and Badge
    SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCovSmallBadge::Formatter
    ])
  end

  # Configure the badge
  SimpleCovSmallBadge.configure do |config|
    config.rounded_border = true
    config.background = "#ffffcc"
    config.output_path = "badges/"
  end

  # Output a message to indicate coverage is being measured
  puts "SimpleCov enabled with badge generation"
end

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
