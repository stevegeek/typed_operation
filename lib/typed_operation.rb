require "typed_operation/version"
require "typed_operation/railtie" if defined?(Rails::Railtie)
require "typed_operation/nilable_type"
require "typed_operation/attribute_builder"
require "typed_operation/curried"
require "typed_operation/base"
require "typed_operation/partially_applied"
require "typed_operation/prepared"

module TypedOperation
  class InvalidOperationError < StandardError; end

  class MissingParameterError < ArgumentError; end

  class ParameterError < TypeError; end
end
