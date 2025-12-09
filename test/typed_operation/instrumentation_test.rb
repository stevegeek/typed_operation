# frozen_string_literal: true

require "test_helper"
require "stringio"

module TypedOperation
  class InstrumentationTest < Minitest::Test
    # Base class for test operations that includes Explainable
    class ExplainableOperation < ::TypedOperation::Base
      include TypedOperation::Explainable
    end

    class SimpleOperation < ExplainableOperation
      param :value, Integer

      def perform
        value * 2
      end
    end

    class FailingOperation < ExplainableOperation
      param :message, String

      def perform
        raise StandardError, message
      end
    end

    class ParentOperation < ExplainableOperation
      param :x, Integer

      def perform
        ChildOperation.call(y: x + 1)
      end
    end

    class ChildOperation < ExplainableOperation
      param :y, Integer

      def perform
        y * 3
      end
    end

    class GrandparentOperation < ExplainableOperation
      param :n, Integer

      def perform
        ParentOperation.call(x: n)
      end
    end

    def setup
      # Clear any leftover trace state between tests
      TypedOperation::Instrumentation.clear_trace!
    end

    # Basic explain functionality

    def test_explain_returns_operation_result
      output = StringIO.new
      result = TypedOperation::Instrumentation.with_output(output) do
        SimpleOperation.explain(value: 5)
      end
      assert_equal 10, result
    end

    def test_explain_prints_trace_to_output
      output = StringIO.new
      TypedOperation::Instrumentation.with_output(output, color: false) do
        SimpleOperation.explain(value: 5)
      end

      trace_output = output.string
      assert_includes trace_output, "SimpleOperation"
      assert_includes trace_output, "✓"
      assert_match(/\[\d+(\.\d+)?ms\]/, trace_output)
    end

    def test_explain_shows_failure_mark_on_exception
      output = StringIO.new

      assert_raises(StandardError) do
        TypedOperation::Instrumentation.with_output(output, color: false) do
          FailingOperation.explain(message: "boom")
        end
      end

      trace_output = output.string
      assert_includes trace_output, "FailingOperation"
      assert_includes trace_output, "✗"
      assert_includes trace_output, "boom"
    end

    def test_explain_reraises_exception
      output = StringIO.new

      error = assert_raises(StandardError) do
        TypedOperation::Instrumentation.with_output(output) do
          FailingOperation.explain(message: "test error")
        end
      end

      assert_equal "test error", error.message
    end

    # Nested operations

    def test_explain_shows_nested_operations
      output = StringIO.new
      result = TypedOperation::Instrumentation.with_output(output, color: false) do
        ParentOperation.explain(x: 5)
      end

      assert_equal 18, result # (5 + 1) * 3

      trace_output = output.string
      assert_includes trace_output, "ParentOperation"
      assert_includes trace_output, "ChildOperation"
    end

    def test_explain_shows_deeply_nested_operations
      output = StringIO.new
      result = TypedOperation::Instrumentation.with_output(output, color: false) do
        GrandparentOperation.explain(n: 2)
      end

      assert_equal 9, result # ((2) + 1) * 3

      trace_output = output.string
      assert_includes trace_output, "GrandparentOperation"
      assert_includes trace_output, "ParentOperation"
      assert_includes trace_output, "ChildOperation"
    end

    # Partial application

    def test_explain_with_partial_application
      output = StringIO.new
      result = TypedOperation::Instrumentation.with_output(output, color: false) do
        SimpleOperation.with(value: 7).explain
      end

      assert_equal 14, result

      trace_output = output.string
      assert_includes trace_output, "SimpleOperation"
      assert_includes trace_output, "✓"
    end

    def test_explain_with_prepared_operation
      output = StringIO.new
      prepared = SimpleOperation.with(value: 3)
      result = TypedOperation::Instrumentation.with_output(output, color: false) do
        prepared.explain
      end

      assert_equal 6, result

      trace_output = output.string
      assert_includes trace_output, "SimpleOperation"
    end

    def test_explain_raises_helpful_error_when_not_explainable
      non_explainable_op = Class.new(::TypedOperation::Base) do
        param :value, Integer

        def perform
          value * 2
        end
      end

      error = assert_raises(TypedOperation::InvalidOperationError) do
        non_explainable_op.with(value: 1).explain
      end

      assert_includes error.message, "does not support .explain"
      assert_includes error.message, "Include TypedOperation::Explainable"
    end

    # Block-based tracing

    def test_explaining_block_traces_multiple_operations
      output = StringIO.new

      result = TypedOperation::Instrumentation.with_output(output, color: false) do
        TypedOperation::Instrumentation.explaining do
          SimpleOperation.call(value: 1)
          SimpleOperation.call(value: 2)
        end
      end

      assert_equal 4, result # Last operation result

      trace_output = output.string
      # Should have two separate traces
      assert_equal 2, trace_output.scan("SimpleOperation").count
    end

    def test_explaining_block_returns_block_result
      output = StringIO.new

      result = TypedOperation::Instrumentation.with_output(output) do
        TypedOperation::Instrumentation.explaining do
          "custom result"
        end
      end

      assert_equal "custom result", result
    end

    def test_explaining_block_reraises_exceptions
      output = StringIO.new

      error = assert_raises(StandardError) do
        TypedOperation::Instrumentation.with_output(output) do
          TypedOperation::Instrumentation.explaining do
            FailingOperation.call(message: "block error")
          end
        end
      end

      assert_equal "block error", error.message
    end

    # Tree formatting

    def test_tree_formatter_uses_arrows_for_chain_flow
      output = StringIO.new
      TypedOperation::Instrumentation.with_output(output, color: false) do
        ParentOperation.explain(x: 1)
      end

      trace_output = output.string
      # Should use arrows to show chain flow
      assert_match(/→/, trace_output)
    end

    def test_tree_formatter_respects_color_option
      output = StringIO.new
      TypedOperation::Instrumentation.with_output(output, color: true) do
        SimpleOperation.explain(value: 1)
      end

      trace_output = output.string
      # Should contain ANSI escape codes
      assert_match(/\e\[\d+m/, trace_output)
    end

    def test_tree_formatter_no_color_when_disabled
      output = StringIO.new
      TypedOperation::Instrumentation.with_output(output, color: false) do
        SimpleOperation.explain(value: 1)
      end

      trace_output = output.string
      # Should not contain ANSI escape codes
      refute_match(/\e\[\d+m/, trace_output)
    end

    # Thread safety

    def test_traces_are_thread_isolated
      outputs = []
      threads = 2.times.map do |i|
        Thread.new do
          output = StringIO.new
          TypedOperation::Instrumentation.with_output(output, color: false) do
            SimpleOperation.explain(value: i)
          end
          outputs << output.string
        end
      end

      threads.each(&:join)

      # Each thread should have its own trace
      assert_equal 2, outputs.size
      outputs.each do |output|
        assert_includes output, "SimpleOperation"
      end
    end

    # Trace data structure

    def test_trace_captures_duration
      trace = TypedOperation::Instrumentation::Trace.new(
        operation_class: SimpleOperation,
        params: {value: 1}
      )

      sleep 0.01 # Small delay to ensure measurable duration
      trace.finish!(result: 2)

      assert trace.duration_ms > 0
      assert trace.duration_ms < 1000 # Sanity check
    end

    def test_trace_captures_exception
      trace = TypedOperation::Instrumentation::Trace.new(
        operation_class: FailingOperation,
        params: {message: "error"}
      )

      exception = StandardError.new("test")
      trace.finish!(exception: exception)

      refute trace.success?
      assert_equal exception, trace.exception
    end

    def test_trace_captures_result
      trace = TypedOperation::Instrumentation::Trace.new(
        operation_class: SimpleOperation,
        params: {value: 5}
      )

      trace.finish!(result: 10)

      assert trace.success?
      assert_equal 10, trace.result
    end

    def test_trace_supports_children
      parent = TypedOperation::Instrumentation::Trace.new(
        operation_class: ParentOperation,
        params: {x: 1}
      )

      child = TypedOperation::Instrumentation::Trace.new(
        operation_class: ChildOperation,
        params: {y: 2}
      )

      parent.add_child(child)

      assert_equal 1, parent.children.size
      assert_equal child, parent.children.first
    end

    # with_output API

    def test_with_output_defaults
      # Default should be $stdout
      assert_equal $stdout, TypedOperation::Instrumentation.output
      # Default color should be true (auto-detect)
      assert_equal true, TypedOperation::Instrumentation.color
    end

    def test_with_output_restores_previous_values
      original_output = TypedOperation::Instrumentation.output
      original_color = TypedOperation::Instrumentation.color

      custom_io = StringIO.new
      TypedOperation::Instrumentation.with_output(custom_io, color: false) do
        assert_equal custom_io, TypedOperation::Instrumentation.output
        assert_equal false, TypedOperation::Instrumentation.color
      end

      assert_equal original_output, TypedOperation::Instrumentation.output
      assert_equal original_color, TypedOperation::Instrumentation.color
    end
  end
end
