require "typed_operation/version"
require "typed_operation/railtie"
require "typed_operation/base"
require "typed_operation/partially_applied"
require "typed_operation/prepared"

module TypedOperation
  class InvalidOperationError < StandardError; end
  class MissingParameterError < ArgumentError; end
  class ParameterError < TypeError; end
end
