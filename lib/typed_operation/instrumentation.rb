# rbs_inline: enabled
# frozen_string_literal: true

require_relative "instrumentation/trace"
require_relative "instrumentation/tree_formatter"

module TypedOperation
  # Provides runtime tracing and debugging capabilities for operations.
  #
  # Usage:
  #   # Trace a single operation call
  #   result = MyOperation.explain(param: value)
  #   # Prints execution tree to stdout, returns the operation result
  #
  #   # Trace with partial application
  #   result = MyOperation.with(partial: value).explain(rest: value)
  #
  #   # Trace a block of code (captures all instrumented operations)
  #   TypedOperation::Instrumentation.explaining do
  #     MyOperation.call(params)
  #     AnotherOperation.call(other_params)
  #   end
  #
  #   # Configure output and color
  #   TypedOperation::Instrumentation.with_output(my_io, color: false) do
  #     MyOperation.explain(param: value)
  #   end
  #
  module Instrumentation
    THREAD_KEY = :typed_operation_trace_stack #: Symbol
    CHAIN_CONTEXT_KEY = :typed_operation_chain_context #: Symbol
    OUTPUT_KEY = :typed_operation_output #: Symbol
    COLOR_KEY = :typed_operation_color #: Symbol

    class << self
      # Execute a block with custom output and color settings.
      #: [T] (IO, ?color: bool?) { () -> T } -> T
      def with_output(io, color: nil, &block)
        old_output = Thread.current[OUTPUT_KEY]
        old_color = Thread.current[COLOR_KEY]
        Thread.current[OUTPUT_KEY] = io
        Thread.current[COLOR_KEY] = color
        yield
      ensure
        Thread.current[OUTPUT_KEY] = old_output
        Thread.current[COLOR_KEY] = old_color
      end

      # Execute a block with tracing enabled, printing the trace tree afterward.
      #: [T] () { () -> T } -> T
      def explaining(&block)
        trace_root = Trace.new(operation_class: BlockExecution, params: {})
        push_trace(trace_root)

        result = nil
        exception = nil
        begin
          result = block.call
        rescue => e
          exception = e
        end

        trace_root.finish!(result: result, exception: exception)
        pop_trace

        formatter = TreeFormatter.new(color: color)
        trace_root.children.each do |child_trace|
          output.puts formatter.format(child_trace)
        end

        raise exception if exception
        result
      end

      #: () -> IO
      def output
        Thread.current[OUTPUT_KEY] || $stdout
      end

      #: () -> bool
      def color
        val = Thread.current[COLOR_KEY]
        val.nil? || val
      end

      #: () -> Trace?
      def current_trace
        stack = Thread.current[THREAD_KEY]
        stack&.last
      end

      #: () -> bool
      def tracing?
        !current_trace.nil?
      end

      #: (Trace) -> void
      def push_trace(trace)
        Thread.current[THREAD_KEY] ||= []
        parent = current_trace
        parent&.add_child(trace)
        Thread.current[THREAD_KEY].push(trace)
      end

      #: () -> Trace?
      def pop_trace
        stack = Thread.current[THREAD_KEY]
        stack&.pop
        Thread.current[THREAD_KEY] = nil if stack.nil? || stack.empty?
      end

      #: () -> void
      def clear_trace!
        Thread.current[THREAD_KEY] = nil
        Thread.current[CHAIN_CONTEXT_KEY] = nil
      end

      #: (pass_mode: Symbol, ?extracted_params: Array[Symbol]?, ?fallback_used: bool) -> void
      def set_chain_context(pass_mode:, extracted_params: nil, fallback_used: false)
        Thread.current[CHAIN_CONTEXT_KEY] = {
          pass_mode: pass_mode,
          extracted_params: extracted_params,
          fallback_used: fallback_used
        }
      end

      #: () -> Hash[Symbol, untyped]?
      def take_chain_context
        ctx = Thread.current[CHAIN_CONTEXT_KEY]
        Thread.current[CHAIN_CONTEXT_KEY] = nil
        ctx
      end
    end

    # Placeholder class for block-based tracing
    class BlockExecution; end

    # Module to be prepended to operation classes to enable tracing.
    # This is automatically included when using `explain`.
    module Traceable
      #: () -> untyped
      def execute_operation
        return super unless Instrumentation.tracing?

        trace = Trace.new(
          operation_class: self.class,
          params: extract_params_for_trace
        )

        # Apply chain context if available
        if (chain_ctx = Instrumentation.take_chain_context)
          trace.pass_mode = chain_ctx[:pass_mode]
          trace.extracted_params = chain_ctx[:extracted_params]
          trace.fallback_used = chain_ctx[:fallback_used]
        end

        Instrumentation.push_trace(trace)

        result = nil
        exception = nil
        begin
          result = super
        rescue => e
          exception = e
        end

        trace.finish!(result: result, exception: exception)
        Instrumentation.pop_trace

        raise exception if exception
        result
      end

      private

      #: () -> Hash[Symbol, untyped]
      def extract_params_for_trace
        self.class.literal_properties.keys.each_with_object({}) do |key, hash|
          hash[key] = send(key)
        end
      rescue
        {}
      end
    end

    # Class methods added to operations for the `explain` entry point.
    module Explainable
      #: (*untyped, **untyped) ?{ () -> untyped } -> untyped
      def explain(*args, **kwargs, &block)
        trace = Trace.new(operation_class: self, params: kwargs.merge(positional: args))
        Instrumentation.push_trace(trace)

        result = nil
        exception = nil
        begin
          result = call(*args, **kwargs, &block)
        rescue => e
          exception = e
        end

        trace.finish!(result: result, exception: exception)
        Instrumentation.pop_trace

        formatter = TreeFormatter.new(color: Instrumentation.color)
        Instrumentation.output.puts formatter.format(trace)

        Instrumentation.clear_trace!

        raise exception if exception
        result
      end
    end
  end
end
