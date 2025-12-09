# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Operations
    # Enables partial application of operation parameters via #with and currying via #curry.
    module PartialApplication
      #: (*untyped, **untyped) -> PartiallyApplied
      def with(...)
        PartiallyApplied.new(self, ...).with
      end
      alias_method :[], :with

      #: () -> Curried
      def curry
        Curried.new(self)
      end
    end
  end
end
