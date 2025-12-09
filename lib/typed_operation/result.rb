# rbs_inline: enabled
# frozen_string_literal: true

require_relative "result/success"
require_relative "result/failure"
require_relative "result/adapters/built_in"
require_relative "result/adapters/dry_monads"
require_relative "result/mixin"

module TypedOperation
  # Result types for representing success and failure outcomes.
  #
  # TypedOperation provides built-in Success and Failure types that work
  # out of the box. You can also configure it to use Dry::Monads or a
  # custom adapter.
  #
  # @example Default usage (built-in types)
  #   result = MyPipeline.call(input)
  #   result.success?  # => true or false
  #   result.value!    # => the value (raises on failure)
  #
  # @example Configure to use Dry::Monads
  #   TypedOperation.configure do |config|
  #     config.result_adapter = :dry_monads
  #   end
  #
  # @example Pattern matching
  #   case result
  #   in Success[value]
  #     handle_success(value)
  #   in Failure[error]
  #     handle_failure(error)
  #   end
  #
  module Result
    # Alias for easy access to UnwrapError from Result module
    UnwrapError = TypedOperation::UnwrapError
  end
end
