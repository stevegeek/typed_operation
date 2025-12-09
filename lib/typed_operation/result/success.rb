# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Result
    # Represents a successful result. Immutable value object.
    class Success
      # @rbs @value: untyped

      attr_reader :value #: untyped

      #: (untyped) -> void
      def initialize(value)
        @value = value
        freeze
      end

      #: () -> true
      def success?
        true
      end

      #: () -> false
      def failure?
        false
      end

      # Returns the wrapped value.
      #: () -> untyped
      def value!
        @value
      end

      # Returns nil for Success.
      #: () -> nil
      def failure
        nil
      end

      # Pattern matching support - array destructuring.
      #: () -> Array[untyped]
      def deconstruct
        [@value]
      end

      # Pattern matching support - hash destructuring.
      #: (Array[Symbol]?) -> Hash[Symbol, untyped]
      def deconstruct_keys(keys)
        h = {value: @value}
        keys ? h.slice(*keys) : h
      end

      #: (untyped) -> bool
      def ==(other)
        other.is_a?(Success) && other.value == @value
      end
      alias_method :eql?, :==

      #: () -> Integer
      def hash
        [self.class, @value].hash
      end

      #: () -> String
      def inspect
        "Success(#{@value.inspect})"
      end
      alias_method :to_s, :inspect
    end
  end
end
