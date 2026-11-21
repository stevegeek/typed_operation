# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Result
    # A common interface over the result types an operation may return:
    # TypedOperation's own Success/Failure, Dry::Monads, Literal's Result, or
    # any custom type with +success?+, +failure?+, +value!+ and +failure+.
    # Build one with Result.wrap; +unwrap+ returns the original result.
    class Wrapper
      #: (untyped) -> void
      def initialize(result)
        @result = result
      end

      #: () -> untyped
      def unwrap
        @result
      end

      #: () -> bool
      def success?
        @result.success?
      end

      #: () -> bool
      def failure?
        @result.failure?
      end

      #: () -> untyped
      def value!
        @result.value!
      end

      # The error carried by a failed result.
      #: () -> untyped
      def error
        @result.failure
      end

      # Whether +error+ can be read from the result.
      #: () -> bool
      def error?
        @result.respond_to?(:failure)
      end
    end

    # Wrapper for Literal::Success and Literal::Failure, which expose the
    # error as +error!+ rather than +failure+.
    class LiteralWrapper < Wrapper
      # @rbs override
      def error
        @result.error!
      end

      # @rbs override
      def error?
        @result.failure?
      end
    end
  end
end
