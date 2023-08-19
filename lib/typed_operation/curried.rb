# frozen_string_literal: true

module TypedOperation
  class Curried
    def initialize(operation_class, partial_operation = nil)
      @operation_class = operation_class
      @partial_operation = partial_operation || operation_class.with
    end

    def call(arg)
      raise ArgumentError, "A prepared operation should not be curried" if @partial_operation.prepared?
      # apply arg to next required parameter and return a new curried operation
      # when all required parameters are applied, invoke operation
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
