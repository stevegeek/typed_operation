# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  class Pipeline
    # Wraps a step operation to handle conditions and error attribution.
    class StepWrapper
      include Result::Mixin

      # @rbs @operation: untyped
      # @rbs @name: Symbol
      # @rbs @condition: (^(untyped) -> boolish)?
      # @rbs @failure_handler: (^(untyped, Symbol) -> untyped)?
      # @rbs @first_step: bool

      #: (untyped, name: Symbol, condition: (^(untyped) -> boolish)?, failure_handler: (^(untyped, Symbol) -> untyped)?, ?first_step: bool) -> void
      def initialize(operation, name:, condition:, failure_handler:, first_step: false)
        @operation = operation
        @name = name
        @condition = condition
        @failure_handler = failure_handler
        @first_step = first_step
      end

      #: (*untyped, **untyped) -> untyped
      def call(*args, **kwargs)
        if @first_step
          call_first_step(*args, **kwargs)
        else
          call_subsequent_step(args.first)
        end
      end

      private

      #: (*untyped, **untyped) -> untyped
      def call_first_step(*args, **kwargs)
        context = kwargs.any? ? kwargs : (args.first || {})

        if @condition && !@condition.call(context)
          return Success(context)
        end

        result = if args.empty? && kwargs.any?
          @operation.call(**kwargs)
        elsif args.any? && kwargs.empty?
          @operation.call(*args)
        elsif args.any? && kwargs.any?
          @operation.call(*args, **kwargs)
        else
          @operation.call
        end

        handle_failure(result)
      end

      #: (untyped) -> untyped
      def call_subsequent_step(input)
        context = normalize_input(input)

        if @condition && !@condition.call(context)
          return Success(context)
        end

        result = @operation.call(context)
        handle_failure(result)
      end

      #: (untyped) -> untyped
      def handle_failure(result)
        if result.failure? && @failure_handler
          return @failure_handler.call(result.failure, @name)
        end
        result
      end

      #: (untyped) -> untyped
      def normalize_input(input)
        case input
        when Hash then input
        when nil then {}
        else input
        end
      end
    end
  end
end
