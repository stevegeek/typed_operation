# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Result
    module Adapters
      # Adapter for Dry::Monads Result type.
      # Requires the dry-monads gem to be available.
      # This is a lazy-loading adapter that only loads dry-monads when instantiated.
      class DryMonads
        #: () -> void
        def initialize
          require "dry-monads"
          extend Dry::Monads[:result]
        end

        # Create a Success result using Dry::Monads.
        #: (untyped) -> untyped
        def success(value)
          Success(value)
        end

        # Create a Failure result using Dry::Monads.
        #: (untyped) -> untyped
        def failure(error)
          Failure(error)
        end

        #: () -> String
        def name
          "Dry::Monads::Result"
        end
      end
    end
  end
end
