# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Result
    module Adapters
      # Default adapter using built-in Success/Failure classes.
      class BuiltIn
        # Create a Success result.
        #: (untyped) -> Result::Success
        def success(value)
          Result::Success.new(value)
        end

        # Create a Failure result.
        #: (untyped) -> Result::Failure
        def failure(error)
          Result::Failure.new(error)
        end

        #: () -> String
        def name
          "TypedOperation::Result (built-in)"
        end
      end
    end
  end
end
