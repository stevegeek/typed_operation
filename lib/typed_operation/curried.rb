# frozen_string_literal: true

module TypedOperation
  # Wraps an operation to support automatic currying, allowing parameters to be
  # provided one at a time. Returns a new Curried instance until all required
  # parameters are satisfied, then executes the operation.
  class Curried
    def initialize(operation_class, partial_operation = nil)
      @operation_class = operation_class
      @partial_operation = partial_operation || operation_class.with
    end

    def call(arg)
      raise ArgumentError, "A prepared operation should not be curried" if @partial_operation.prepared?

      next_partially_applied = if next_parameter_positional?
        @partial_operation.with(arg)
      else
        @partial_operation.with(next_keyword_parameter => arg)
      end
      if next_partially_applied.prepared?
        next_partially_applied.call
      else
        Curried.new(@operation_class, next_partially_applied)
      end
    end

    def to_proc
      method(:call).to_proc
    end

    private

    def next_keyword_parameter
      remaining = @operation_class.required_keyword_parameters - @partial_operation.keyword_args.keys
      remaining.first
    end

    def next_parameter_positional?
      @partial_operation.positional_args.size < @operation_class.required_positional_parameters.size
    end
  end
end
