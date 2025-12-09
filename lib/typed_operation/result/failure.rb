# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Error raised when trying to unwrap a Failure result.
  class UnwrapError < StandardError; end

  module Result
    # Represents a failed result. Immutable value object.
    class Failure
      # @rbs @error: untyped

      attr_reader :error #: untyped

      #: (untyped) -> void
      def initialize(error)
        @error = error
        freeze
      end

      #: () -> false
      def success?
        false
      end

      #: () -> true
      def failure?
        true
      end

      # Raises UnwrapError since this is a Failure.
      #: () -> bot
      def value!
        raise UnwrapError, "Cannot unwrap Failure: #{@error.inspect}"
      end

      # Returns the wrapped error.
      #: () -> untyped
      def failure
        @error
      end

      # Pattern matching support - array destructuring.
      #: () -> Array[untyped]
      def deconstruct
        @error.is_a?(::Array) ? @error : [@error]
      end

      # Pattern matching support - hash destructuring.
      # Delegates to the inner error if it responds to deconstruct_keys.
      #: (Array[Symbol]?) -> Hash[Symbol, untyped]
      def deconstruct_keys(keys)
        if @error.respond_to?(:deconstruct_keys)
          @error.deconstruct_keys(keys)
        else
          {error: @error, failure: @error}
        end
      end

      #: (untyped) -> bool
      def ==(other)
        other.is_a?(Failure) && other.error == @error
      end
      alias_method :eql?, :==

      #: () -> Integer
      def hash
        [self.class, @error].hash
      end

      #: () -> String
      def inspect
        "Failure(#{@error.inspect})"
      end
      alias_method :to_s, :inspect
    end
  end
end
