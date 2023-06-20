require "typed_operation/version"
require "typed_operation/railtie"
require "typed_operation/base"
require "typed_operation/partially_applied"
require "typed_operation/prepared"

module TypedOperation
  class ParameterError < StandardError; end
end
