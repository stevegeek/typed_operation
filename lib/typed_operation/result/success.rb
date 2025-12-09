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
        @value.is_a?(::Array) ? @value : [@value]
      end

      # Pattern matching support - hash destructuring.
      # Delegates to the inner value if it responds to deconstruct_keys.
      #: (Array[Symbol]?) -> Hash[Symbol, untyped]
      def deconstruct_keys(keys)
        if @value.respond_to?(:deconstruct_keys)
          @value.deconstruct_keys(keys)
        else
          {value: @value}
        end
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
