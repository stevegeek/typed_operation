require "literal"

require "typed_operation/version"
require "typed_operation/railtie" if defined?(Rails::Railtie)
require "typed_operation/operations/introspection"
require "typed_operation/operations/parameters"
require "typed_operation/operations/partial_application"
require "typed_operation/operations/lifecycle"
require "typed_operation/operations/property_builder"
require "typed_operation/operations/executable"
require "typed_operation/operations/composition"
require "typed_operation/curried"
require "typed_operation/immutable_base"
require "typed_operation/base"
require "typed_operation/partially_applied"
require "typed_operation/prepared"
require "typed_operation/chains/chained_operation"
require "typed_operation/chains/sequence_chain"
require "typed_operation/chains/splat_chain"
require "typed_operation/chains/smart_chain"
require "typed_operation/chains/map_chain"
require "typed_operation/chains/fallback_chain"
require "typed_operation/context"
require "typed_operation/pipeline"

# TypedOperation provides a framework for defining type-safe, composable operations
# with support for partial application, currying, and parameter validation.
module TypedOperation
  class InvalidOperationError < StandardError; end

  class MissingParameterError < ArgumentError; end

  class ParameterError < TypeError; end
end
