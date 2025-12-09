# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Error raised when trying to unwrap a Failure result.
  class UnwrapError < StandardError; end

  module Result
    # Represents a failed result. Immutable value object.
    #
    # @rbs generic Error
    class Failure
      # @rbs @error: Error

      attr_reader :error #: Error

      #: (Error) -> void
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
      #: () -> Error
      def failure
        @error
      end

      # Pattern matching support - array destructuring.
      #: () -> [Error]
      def deconstruct
        [@error]
      end

      # Pattern matching support - hash destructuring.
      #: (Array[Symbol]?) -> Hash[Symbol, Error]
      def deconstruct_keys(keys)
        h = {error: @error, failure: @error}
        keys ? h.slice(*keys) : h
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
