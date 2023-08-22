if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2.0")
  require "polyfill-data"
end

require "typed_operation/version"
require "typed_operation/railtie" if defined?(Rails::Railtie)
require "typed_operation/operations/introspection"
require "typed_operation/operations/parameters"
require "typed_operation/operations/partial_application"
require "typed_operation/operations/callable"
require "typed_operation/operations/lifecycle"
require "typed_operation/operations/deconstruct"
require "typed_operation/operations/attribute_builder"
require "typed_operation/curried"
require "typed_operation/immutable_base"
require "typed_operation/base"
require "typed_operation/partially_applied"
require "typed_operation/prepared"

module TypedOperation
  class InvalidOperationError < StandardError; end

  class MissingParameterError < ArgumentError; end

  class ParameterError < TypeError; end
end
