# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  class Pipeline
    # Wraps a step operation to handle conditions and error attribution.
    class StepWrapper
      include Result::Mixin

      # @rbs @operation: untyped
      # @rbs @name: Symbol
      # @rbs @condition: (^(untyped) -> bool)?
      # @rbs @failure_handler: (^(untyped, Symbol) -> untyped)?
      # @rbs @first_step: bool
      # @rbs @uses_kwargs: bool

      #: (untyped, name: Symbol, condition: (^(untyped) -> bool)?, failure_handler: (^(untyped, Symbol) -> untyped)?, ?first_step: bool) -> void
      def initialize(operation, name:, condition:, failure_handler:, first_step: false)
        @operation = operation
        @name = name
        @condition = condition
        @failure_handler = failure_handler
        @first_step = first_step
        @uses_kwargs = uses_kwargs?(operation)
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

        if (condition = @condition) && !condition.call(context)
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

        if (condition = @condition) && !condition.call(context)
          return Success(context)
        end

        result = if @uses_kwargs && context.is_a?(Hash)
          @operation.call(**context)
        else
          @operation.call(context)
        end
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

      #: (untyped) -> bool
      def uses_kwargs?(operation)
        op_class = extract_operation_class(operation)
        return false unless op_class.respond_to?(:positional_parameters)

        positional = op_class.positional_parameters
        keywords = op_class.keyword_parameters

        keywords.any? && positional.empty?
      end

      #: (untyped) -> untyped
      def extract_operation_class(operation)
        case operation
        when Class then operation
        when TypedOperation::PartiallyApplied then operation.operation_class
        when Proc then nil
        else operation.class
        end
      end
    end
  end
end
