# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Result
    module Adapters
      # Adapter for Literal's Result type (Literal::Success and Literal::Failure).
      # Results are created with untyped success and failure types; use
      # Literal::Result(success_type, failure_type) directly for typed results.
      class Literal
        # Create a Success result using Literal.
        #: (untyped) -> ::Literal::Success
        def success(value)
          ::Literal::Success.new(value, success_type: ::Literal::Types._Any?, failure_type: ::Literal::Types._Any?)
        end

        # Create a Failure result using Literal.
        #: (untyped) -> ::Literal::Failure
        def failure(error)
          ::Literal::Failure.new(error, success_type: ::Literal::Types._Any?, failure_type: ::Literal::Types._Any?)
        end

        #: () -> String
        def name
          "Literal::Result"
        end
      end
    end
  end
end
