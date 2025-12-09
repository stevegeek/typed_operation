# rbs_inline: enabled
# frozen_string_literal: true

require_relative "pipeline/step_wrapper"
require_relative "pipeline/empty_pipeline_chain"
require_relative "pipeline/chainable_wrapper"
require_relative "pipeline/builder"

module TypedOperation
  # DSL for building declarative pipelines of operations.
  # Pipeline is syntactic sugar over the composition/chaining system.
  # Internally builds chains, adding named steps, conditions, and error attribution.
  class Pipeline
    # @rbs @chain: untyped

    attr_reader :steps #: Array[Hash[Symbol, untyped]]
    attr_reader :failure_handler #: (^(untyped, Symbol) -> untyped)?

    # Build a new pipeline using the DSL.
    #: () { () -> void } -> Pipeline
    def self.build(&block)
      builder = Builder.new
      builder.instance_eval(&block)
      new(builder.steps, builder.failure_handler)
    end

    #: (?Array[Hash[Symbol, untyped]], ?(^(untyped, Symbol) -> untyped)?) -> void
    def initialize(steps = [], failure_handler = nil)
      @steps = steps.freeze
      @failure_handler = failure_handler
      @chain = nil
    end

    # Execute the pipeline by delegating to the internal chain.
    #: (*untyped, **untyped) -> untyped
    def call(*args, **kwargs)
      chain.call(*args, **kwargs)
    end

    # Append an operation as a new step, returning a new Pipeline.
    #: (untyped, ?name: Symbol?, ?if: (^(untyped) -> boolish)?) -> Pipeline
    def append(operation, name: nil, if: nil)
      condition = binding.local_variable_get(:if)
      new_step = {
        type: :step,
        name: name || derive_name(operation),
        operation: operation,
        condition: condition
      }
      self.class.new(@steps + [new_step], @failure_handler)
    end

    # Compose with another pipeline, merging steps.
    #: (Pipeline, ?on_failure: (:left | :right | ^(untyped, Symbol) -> untyped)?) -> Pipeline
    def compose(other, on_failure: nil)
      handler = resolve_failure_handlers(other, on_failure)
      self.class.new(@steps + other.steps, handler)
    end

    # Smart composition operator.
    #: (Pipeline | untyped) -> Pipeline
    def +(other)
      case other
      when Pipeline
        compose(other)
      else
        append(other)
      end
    end

    # Convert to a bare chain for full Composition flexibility.
    #: () -> ChainableWrapper
    def to_chain
      ChainableWrapper.new(self)
    end

    private

    #: () -> untyped
    def chain
      @chain ||= build_chain
    end

    #: () -> untyped
    def build_chain
      return EmptyPipelineChain.new if @steps.empty?

      @steps.each_with_index.reduce(nil) do |current_chain, (step, index)|
        is_first = index == 0
        wrapped = wrap_step(step, first_step: is_first)

        if current_chain.nil?
          wrapped
        else
          combine_into_chain(current_chain, step, wrapped)
        end
      end
    end

    #: (untyped, Hash[Symbol, untyped], untyped) -> untyped
    def combine_into_chain(current_chain, step, wrapped)
      case step[:type]
      when :fallback
        FallbackChain.new(current_chain, wrapped)
      when :transform
        MapChain.new(current_chain, wrapped)
      else
        SequenceChain.new(current_chain, wrapped)
      end
    end

    #: (Hash[Symbol, untyped], ?first_step: bool) -> untyped
    def wrap_step(step, first_step: false)
      case step[:type]
      when :transform
        step[:operation]
      when :fallback
        wrap_fallback(step)
      else
        StepWrapper.new(
          step[:operation],
          name: step[:name],
          condition: step[:condition],
          failure_handler: @failure_handler,
          first_step: first_step
        )
      end
    end

    #: (Hash[Symbol, untyped]) -> untyped
    def wrap_fallback(step)
      if step[:operation].is_a?(Proc)
        step[:operation]
      else
        StepWrapper.new(
          step[:operation],
          name: step[:name] || :fallback,
          condition: nil,
          failure_handler: @failure_handler
        )
      end
    end

    #: (Pipeline, (:left | :right | ^(untyped, Symbol) -> untyped)?) -> (^(untyped, Symbol) -> untyped)?
    def resolve_failure_handlers(other, on_failure)
      return @failure_handler if other.failure_handler.nil?
      return other.failure_handler if @failure_handler.nil?

      case on_failure
      when :left then @failure_handler
      when :right then other.failure_handler
      when Proc then on_failure
      when nil
        raise ArgumentError,
          "Both pipelines have failure handlers. Specify on_failure: :left, :right, or a Proc"
      else
        raise ArgumentError, "Invalid on_failure option: #{on_failure.inspect}"
      end
    end

    #: (untyped) -> Symbol
    def derive_name(operation)
      return :anonymous if operation.nil?
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
