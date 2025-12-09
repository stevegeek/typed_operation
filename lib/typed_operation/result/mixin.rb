# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Result
    # Mixin providing Success/Failure factory methods to chain classes.
    # Include this module to call Success(value) and Failure(error) directly.
    module Mixin
      private

      # Create a Success result using the configured adapter.
      #: (untyped) -> untyped
      def Success(value)
        TypedOperation.configuration.result_adapter.success(value)
      end

      # Create a Failure result using the configured adapter.
      #: (untyped) -> untyped
      def Failure(error)
        TypedOperation.configuration.result_adapter.failure(error)
      end
    end
  end
end
