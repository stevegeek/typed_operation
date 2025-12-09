# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  class Pipeline
    # Builder class for the Pipeline DSL.
    class Builder
      # @rbs @steps: Array[Hash[Symbol, untyped]]
      # @rbs @failure_handler: (^(untyped, Symbol) -> untyped)?

      attr_reader :steps #: Array[Hash[Symbol, untyped]]
      attr_reader :failure_handler #: (^(untyped, Symbol) -> untyped)?

      #: () -> void
      def initialize
        @steps = []
        @failure_handler = nil
      end

      # Define a step in the pipeline.
      #: (Symbol | untyped, ?untyped, ?if: (^(untyped) -> boolish)?) -> void
      def step(name_or_operation, operation = nil, if: nil)
        condition = binding.local_variable_get(:if)

        @steps << if operation
          {
            type: :step,
            name: name_or_operation,
            operation: operation,
            condition: condition
          }
        else
          {
            type: :step,
            name: derive_name(name_or_operation),
            operation: name_or_operation,
            condition: condition
          }
        end
      end

      # Define a transform step that maps the success value.
      #: () { (untyped) -> untyped } -> void
      def transform(&block)
        @steps << {
          type: :transform,
          name: :transform,
          operation: block,
          condition: nil
        }
      end

      # Define a fallback for error recovery.
      #: (?untyped) ?{ (untyped) -> untyped } -> void
      def fallback(operation = nil, &block)
        @steps << {
          type: :fallback,
          name: operation ? derive_name(operation) : :fallback,
          operation: operation || block,
          condition: nil
        }
      end
      alias_method :or_else, :fallback

      # Define a failure handler for the pipeline.
      #: () { (untyped, Symbol) -> untyped } -> void
      def on_failure(&block)
        @failure_handler = block
      end

      private

      #: (untyped) -> Symbol
      def derive_name(operation)
        return :anonymous unless operation.respond_to?(:name) && operation.name

        operation.name
          .split("::")
          .last
          .gsub(/Operation$/, "")
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
          .to_sym
      end
    end
  end
end
