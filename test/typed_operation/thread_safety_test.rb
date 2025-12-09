# frozen_string_literal: true

require "test_helper"
require "stringio"
require "dry-monads"

module TypedOperation
  class ThreadSafetyTest < Minitest::Test
    # Operations for testing - include Explainable for tracing
    class ExplainableOperation < ::TypedOperation::Base
      include TypedOperation::Explainable
    end

    class SimpleOp < ExplainableOperation
      param :value, Integer
      param :thread_id, String, default: -> { Thread.current.object_id.to_s }

      def perform
        # Small delay to increase chance of race conditions
        sleep(rand * 0.01)
        {value: value * 2, thread_id: thread_id}
      end
    end

    class FailingOp < ExplainableOperation
      param :message, String

      def perform
        raise StandardError, message
      end
    end

    class ParentOp < ExplainableOperation
      param :x, Integer

      def perform
        ChildOp.call(y: x + 1)
      end
    end

    class ChildOp < ExplainableOperation
      param :y, Integer

      def perform
        {result: y * 3, thread: Thread.current.object_id}
      end
    end

    class SlowOp < ExplainableOperation
      param :duration, Float
      param :id, Integer

      def perform
        sleep(duration)
        {id: id, completed_at: Time.now}
      end
    end

    def setup
      # Clear any leftover trace state between tests
      TypedOperation::Instrumentation.clear_trace!
    end

    def teardown
      # Ensure cleanup after each test
      TypedOperation::Instrumentation.clear_trace!
    end

    # =========================================================================
    # POSITIVE TESTS: Thread Isolation Works Correctly
    # =========================================================================

    def test_concurrent_operations_have_isolated_traces
      # Run multiple operations concurrently and verify each thread
      # gets its own isolated trace state
      results = []
      mutex = Mutex.new

      threads = 10.times.map do |i|
        Thread.new do
          output = StringIO.new
          result = TypedOperation::Instrumentation.with_output(output, color: false) { SimpleOp.explain(value: i) }

          mutex.synchronize do
            results << {
              input: i,
              output: result,
              trace: output.string,
              thread_id: Thread.current.object_id
            }
          end
        end
      end

      threads.each(&:join)

      # Verify all 10 operations completed
      assert_equal 10, results.size

      # Verify each result matches its input (no cross-contamination)
      results.each do |r|
        assert_equal r[:input] * 2, r[:output][:value]
        assert_includes r[:trace], "SimpleOp"
      end

      # Verify unique thread IDs
      thread_ids = results.map { |r| r[:thread_id] }
      assert_equal 10, thread_ids.uniq.size
    end

    def test_nested_operations_in_threads_are_isolated
      # Each thread runs Parent -> Child operations
      # Verify the nested traces don't mix between threads
      results = []
      mutex = Mutex.new

      threads = 5.times.map do |i|
        Thread.new do
          output = StringIO.new
          result = TypedOperation::Instrumentation.with_output(output, color: false) { ParentOp.explain(x: i * 10) }

          mutex.synchronize do
            results << {
              input: i * 10,
              output: result,
              trace: output.string,
              thread_id: Thread.current.object_id
            }
          end
        end
      end

      threads.each(&:join)

      # Verify all operations completed correctly
      assert_equal 5, results.size

      results.each do |r|
        expected = (r[:input] + 1) * 3
        assert_equal expected, r[:output][:result]
        # Trace should show both parent and child
        assert_includes r[:trace], "ParentOp"
        assert_includes r[:trace], "ChildOp"
      end
    end

    def test_thread_local_state_not_visible_to_other_threads
      # Explicitly verify that Thread.current[KEY] is isolated
      key = :typed_operation_trace_stack

      thread1_saw_thread2_state = false
      thread2_set_value = false

      barrier = Queue.new

      t1 = Thread.new do
        # Wait for t2 to set its state
        barrier.pop
        # Check if we can see t2's state (we shouldn't)
        thread1_saw_thread2_state = !Thread.current[key].nil?
      end

      t2 = Thread.new do
        Thread.current[key] = [:thread2_trace]
        thread2_set_value = true
        barrier << :ready
        sleep 0.1 # Keep state alive while t1 checks
      end

      t1.join
      t2.join

      assert thread2_set_value, "Thread 2 should have set its state"
      refute thread1_saw_thread2_state, "Thread 1 should NOT see Thread 2's state"
    end

    def test_high_concurrency_operations_all_succeed
      # Stress test with many concurrent operations
      thread_count = 50
      results = []
      errors = []
      mutex = Mutex.new

      threads = thread_count.times.map do |i|
        Thread.new do
          result = SimpleOp.call(value: i)
          mutex.synchronize { results << {input: i, output: result} }
        rescue => e
          mutex.synchronize { errors << {input: i, error: e} }
        end
      end

      threads.each(&:join)

      # All operations should succeed
      assert_empty errors, "Expected no errors but got: #{errors.inspect}"
      assert_equal thread_count, results.size

      # Verify each result is correct
      results.each do |r|
        assert_equal r[:input] * 2, r[:output][:value]
      end
    end

    def test_explaining_block_isolated_per_thread
      # Multiple threads using Instrumentation.explaining blocks
      results = []
      mutex = Mutex.new

      threads = 5.times.map do |i|
        Thread.new do
          output = StringIO.new
          result = TypedOperation::Instrumentation.with_output(output, color: false) do
            TypedOperation::Instrumentation.explaining do
              SimpleOp.call(value: i)
              SimpleOp.call(value: i + 100)
            end
          end

          mutex.synchronize do
            results << {
              thread: i,
              result: result,
              trace: output.string
            }
          end
        end
      end

      threads.each(&:join)

      assert_equal 5, results.size

      results.each do |r|
        # Each trace should have exactly 2 SimpleOp calls
        count = r[:trace].scan("SimpleOp").count
        assert_equal 2, count, "Thread #{r[:thread]} should have 2 SimpleOp traces, got #{count}"
      end
    end

    # =========================================================================
    # BUG EXPOSURE TESTS: Demonstrate Exception Cleanup Issue
    # =========================================================================

    def test_trace_state_leaks_after_exception_in_traceable_execute
      # This test EXPOSES THE BUG: When an exception occurs during tracing,
      # the trace state is not properly cleaned up.
      #
      # In Traceable#execute_operation (instrumentation.rb lines 106-136):
      #   Instrumentation.push_trace(trace)
      #   result = super  # <-- If this raises...
      #   Instrumentation.pop_trace  # <-- ...this is never called!
      #
      # However, looking at the code more carefully, the exception IS caught
      # and pop_trace IS called in the ensure-like pattern. Let's verify.

      # First, ensure clean state
      TypedOperation::Instrumentation.clear_trace!
      assert_nil Thread.current[:typed_operation_trace_stack]

      # Call a failing operation with explain
      output = StringIO.new
      begin
        TypedOperation::Instrumentation.with_output(output, color: false) { FailingOp.explain(message: "intentional failure") }
      rescue
        # Expected
      end

      # The current implementation SHOULD clean up, but let's verify
      # Actually looking at the code, Explainable#explain (lines 151-176)
      # DOES have proper cleanup with clear_trace! at line 172
      # But what about when we're NOT using explain, just tracing?

      # Let's check the raw state after the explain call
      # This should be nil because explain calls clear_trace!
      assert_nil Thread.current[:typed_operation_trace_stack],
        "BUG: Trace state should be nil after explain completes (even with exception)"
    end

    def test_trace_state_after_exception_in_explaining_block
      # Test exception cleanup in Instrumentation.explaining block
      TypedOperation::Instrumentation.clear_trace!

      output = StringIO.new
      begin
        TypedOperation::Instrumentation.with_output(output, color: false) do
          TypedOperation::Instrumentation.explaining do
            FailingOp.call(message: "block failure")
          end
        end
      rescue
        # Expected
      end

      # After explaining block completes (even with exception),
      # the trace state should be cleaned up
      # Looking at lines 29-52, explaining DOES have rescue and cleanup
      assert_nil Thread.current[:typed_operation_trace_stack],
        "Trace state should be nil after explaining block (even with exception)"
    end

    def test_exception_in_one_thread_doesnt_affect_other_threads
      # Verify that an exception in one thread doesn't corrupt
      # the trace state of other threads
      results = []
      errors = []
      mutex = Mutex.new

      threads = []

      # Thread that will fail
      threads << Thread.new do
        output = StringIO.new
        TypedOperation::Instrumentation.with_output(output, color: false) { FailingOp.explain(message: "thread failure") }
      rescue => e
        mutex.synchronize { errors << e }
      end

      # Threads that should succeed
      5.times do |i|
        threads << Thread.new do
          # Small delay to let the failing thread start
          sleep(0.01)
          output = StringIO.new
          result = TypedOperation::Instrumentation.with_output(output, color: false) { SimpleOp.explain(value: i) }
          mutex.synchronize { results << {input: i, output: result} }
        end
      end

      threads.each(&:join)

      # Verify the exception was caught
      assert_equal 1, errors.size, "Expected 1 error, got #{errors.size}: #{errors.inspect}"

      # Verify all other threads succeeded
      assert_equal 5, results.size, "Expected 5 results, got #{results.size}"

      # Verify each result is correct (order not guaranteed)
      results.each do |r|
        assert_equal r[:input] * 2, r[:output][:value],
          "Result for input #{r[:input]} should be #{r[:input] * 2}"
      end
    end

    def test_rapid_explain_cycles_under_contention
      # Rapidly push/pop traces in multiple threads to stress test
      # the thread-local storage
      iterations = 100
      thread_count = 10
      results = []
      errors = []
      mutex = Mutex.new

      threads = thread_count.times.map do |t|
        Thread.new do
          iterations.times do |i|
            output = StringIO.new
            result = TypedOperation::Instrumentation.with_output(output, color: false) { SimpleOp.explain(value: t * 1000 + i) }
            mutex.synchronize { results << result }
          rescue => e
            mutex.synchronize { errors << {thread: t, iteration: i, error: e} }
          end
        end
      end

      threads.each(&:join)

      assert_empty errors, "Expected no errors in rapid cycles: #{errors.first(5).inspect}"
      assert_equal thread_count * iterations, results.size
    end

    # =========================================================================
    # EDGE CASE TESTS: Potential Race Conditions
    # =========================================================================

    def test_chain_context_isolation_between_threads
      # The chain context (set_chain_context / take_chain_context) uses
      # a separate thread-local key. Verify it's isolated.

      results = []
      mutex = Mutex.new

      threads = 5.times.map do |i|
        Thread.new do
          # Set chain context
          TypedOperation::Instrumentation.set_chain_context(
            pass_mode: :"mode_#{i}",
            extracted_params: {thread: i}
          )

          # Small delay
          sleep(rand * 0.01)

          # Take it back
          ctx = TypedOperation::Instrumentation.take_chain_context

          mutex.synchronize do
            results << {thread: i, context: ctx}
          end
        end
      end

      threads.each(&:join)

      assert_equal 5, results.size

      # Each thread should get back its own context
      results.each do |r|
        assert_equal :"mode_#{r[:thread]}", r[:context][:pass_mode]
        assert_equal({thread: r[:thread]}, r[:context][:extracted_params])
      end
    end

    def test_trace_children_not_shared_between_threads
      # Verify that when multiple threads create nested traces,
      # the children arrays don't get mixed up

      # This would be a bug if Trace objects were somehow shared,
      # which shouldn't happen in normal use since each trace is
      # created per-thread
      results = []
      mutex = Mutex.new

      threads = 5.times.map do |i|
        Thread.new do
          output = StringIO.new
          TypedOperation::Instrumentation.with_output(output, color: false) { ParentOp.explain(x: i) }

          # Parse the trace output to count children
          trace_lines = output.string.lines
          child_count = trace_lines.count { |l| l.include?("ChildOp") }

          mutex.synchronize do
            results << {
              thread: i,
              child_count: child_count,
              trace: output.string
            }
          end
        end
      end

      threads.each(&:join)

      # Each parent should have exactly 1 child
      results.each do |r|
        assert_equal 1, r[:child_count],
          "Thread #{r[:thread]} should have 1 child, got #{r[:child_count]}\nTrace: #{r[:trace]}"
      end
    end

    # =========================================================================
    # BUG DEMONSTRATION: Direct Test of Traceable Module Cleanup
    # =========================================================================

    def test_traceable_module_exception_handling
      # This test directly examines the Traceable module's exception handling
      # Looking at instrumentation.rb lines 106-136:
      #
      # def execute_operation
      #   return super unless Instrumentation.tracing?
      #   trace = Trace.new(...)
      #   Instrumentation.push_trace(trace)
      #   result = nil
      #   exception = nil
      #   begin
      #     result = super
      #   rescue => e
      #     exception = e
      #   end
      #   trace.finish!(result: result, exception: exception)
      #   Instrumentation.pop_trace  # <-- This IS called even on exception
      #   raise exception if exception
      #   result
      # end
      #
      # So actually, the Traceable module DOES handle exceptions correctly!
      # The pop_trace is outside the begin/rescue, so it always runs.
      # This is NOT a bug - it's just an unusual pattern.

      TypedOperation::Instrumentation.clear_trace!

      # Start a tracing context
      TypedOperation::Instrumentation.with_output(StringIO.new, color: false) do
        TypedOperation::Instrumentation.explaining do
          # Now we're tracing - current_trace should exist
          assert TypedOperation::Instrumentation.tracing?

          # Call a failing operation
          begin
            FailingOp.call(message: "test exception")
          rescue
            # Expected
          end

          # After the failing op, we should still be in the explaining block's trace
          # but the failed op's trace should have been popped
          assert TypedOperation::Instrumentation.tracing?,
            "Should still be tracing after exception in nested op"
        end
      end

      # After explaining block, should be clean
      refute TypedOperation::Instrumentation.tracing?
    end

    def test_deeply_nested_exceptions_cleanup
      # Test that deeply nested operations with exceptions still clean up

      deep_op = Class.new(ExplainableOperation) do
        param :depth, Integer
        param :fail_at, Integer, default: -1

        def perform
          raise "Intentional failure at depth #{depth}" if depth == fail_at

          if depth > 0
            self.class.call(depth: depth - 1, fail_at: fail_at)
          else
            {reached_bottom: true}
          end
        end
      end

      TypedOperation::Instrumentation.clear_trace!

      # Fail at depth 2 out of 5
      output = StringIO.new
      begin
        TypedOperation::Instrumentation.with_output(output, color: false) { deep_op.explain(depth: 5, fail_at: 2) }
      rescue
        # Expected
      end

      # Trace should be cleaned up
      assert_nil Thread.current[:typed_operation_trace_stack],
        "Trace state should be nil after deep nested exception"
    end

    # =========================================================================
    # DESIGN OBSERVATION TESTS: Not bugs, but inconsistencies worth noting
    # =========================================================================

    def test_pop_trace_vs_take_chain_context_cleanup_patterns
      # This test documents an INCONSISTENCY in the cleanup patterns:
      #
      # pop_trace (line 72-76):
      #   stack&.pop
      #   Thread.current[THREAD_KEY] = nil if stack&.empty?
      #   -> Only sets to nil if empty
      #
      # take_chain_context (line 93-96):
      #   ctx = Thread.current[CHAIN_CONTEXT_KEY]
      #   Thread.current[CHAIN_CONTEXT_KEY] = nil
      #   -> Always sets to nil
      #
      # This means:
      # - Trace stack persists (as empty array) after all pops until explicitly cleared
      # - Chain context is always fully cleared

      TypedOperation::Instrumentation.clear_trace!

      # Push and pop a trace
      trace = TypedOperation::Instrumentation::Trace.new(
        operation_class: SimpleOp,
        params: {value: 1}
      )
      TypedOperation::Instrumentation.push_trace(trace)
      TypedOperation::Instrumentation.pop_trace

      # After pop, the key should be nil (since stack is empty)
      # This IS the current behavior - the inconsistency is just stylistic
      trace_key_value = Thread.current[:typed_operation_trace_stack]
      assert_nil trace_key_value,
        "Trace key should be nil after popping last trace (current behavior)"

      # Now test chain context
      TypedOperation::Instrumentation.set_chain_context(
        pass_mode: :test,
        extracted_params: {}
      )
      TypedOperation::Instrumentation.take_chain_context

      chain_key_value = Thread.current[:typed_operation_chain_context]
      assert_nil chain_key_value,
        "Chain context key should be nil after take"
    end

    def test_manual_push_without_pop_leaves_state
      # This test shows what happens if push_trace is called
      # without a corresponding pop_trace (outside of explain/explaining)
      # This is a potential footgun for anyone using the low-level API directly

      TypedOperation::Instrumentation.clear_trace!

      # Manually push a trace without popping
      trace = TypedOperation::Instrumentation::Trace.new(
        operation_class: SimpleOp,
        params: {value: 1}
      )
      TypedOperation::Instrumentation.push_trace(trace)

      # State should still be there
      assert TypedOperation::Instrumentation.tracing?,
        "Should still be tracing after push without pop"

      # This is the "leaked" state that could accumulate in long-running processes
      # if someone uses the low-level API incorrectly
      stack = Thread.current[:typed_operation_trace_stack]
      assert_equal 1, stack.size, "Stack should have 1 trace"

      # Clean up for other tests
      TypedOperation::Instrumentation.clear_trace!
    end

    def test_stress_test_trace_accumulation
      # This test verifies that normal usage doesn't accumulate state
      # by running many operations and checking state afterward

      TypedOperation::Instrumentation.clear_trace!

      100.times do |i|
        output = StringIO.new
        TypedOperation::Instrumentation.with_output(output, color: false) { SimpleOp.explain(value: i) }
      end

      # After 100 explains, state should be clean
      assert_nil Thread.current[:typed_operation_trace_stack],
        "No trace state should accumulate after many explain calls"
      assert_nil Thread.current[:typed_operation_chain_context],
        "No chain context should accumulate after many explain calls"
    end

    def test_explaining_block_without_operations_still_cleans_up
      # Edge case: what if explaining block doesn't call any operations?

      TypedOperation::Instrumentation.clear_trace!

      output = StringIO.new
      result = TypedOperation::Instrumentation.with_output(output, color: false) do
        TypedOperation::Instrumentation.explaining do
          # No operations called
          "just a value"
        end
      end

      assert_equal "just a value", result
      assert_nil Thread.current[:typed_operation_trace_stack],
        "State should be clean even with no operations in explaining block"
    end

    def test_concurrent_set_and_take_chain_context
      # Stress test the chain context under concurrent access
      # Each thread sets its own context and should get it back

      iterations = 100
      thread_count = 10
      results = []
      errors = []
      mutex = Mutex.new

      threads = thread_count.times.map do |t|
        Thread.new do
          iterations.times do |i|
            context_value = "thread_#{t}_iter_#{i}"

            TypedOperation::Instrumentation.set_chain_context(
              pass_mode: context_value.to_sym,
              extracted_params: {value: context_value}
            )

            # Small random delay to increase interleaving
            sleep(rand * 0.001)

            ctx = TypedOperation::Instrumentation.take_chain_context

            # Verify we got back our own context
            if ctx[:pass_mode] == context_value.to_sym
              mutex.synchronize { results << true }
            else
              mutex.synchronize do
                errors << {
                  thread: t,
                  iteration: i,
                  expected: context_value,
                  got: ctx[:pass_mode]
                }
              end
            end
          rescue => e
            mutex.synchronize { errors << {thread: t, iteration: i, error: e} }
          end
        end
      end

      threads.each(&:join)

      assert_empty errors, "Chain context should be isolated: #{errors.first(5).inspect}"
      assert_equal thread_count * iterations, results.size,
        "All iterations should succeed"
    end

    # =========================================================================
    # COMPREHENSIVE THREAD SAFETY TESTS: All gem features
    # =========================================================================

    # Test that operation classes themselves are thread-safe
    # (class-level introspection methods)
    def test_class_introspection_thread_safe
      # Create an operation class
      op_class = Class.new(::TypedOperation::Base) do
        param :a, Integer
        param :b, String
        positional_param :c, Float

        def perform
          {a: a, b: b, c: c}
        end
      end

      results = []
      errors = []
      mutex = Mutex.new

      # Multiple threads introspecting the same class
      threads = 20.times.map do
        Thread.new do
          100.times do
            # These are class-level methods that read class state
            pos = op_class.positional_parameters
            kw = op_class.keyword_parameters
            req_pos = op_class.required_positional_parameters
            req_kw = op_class.required_keyword_parameters

            mutex.synchronize do
              results << {
                positional: pos,
                keyword: kw,
                required_positional: req_pos,
                required_keyword: req_kw
              }
            end
          rescue => e
            mutex.synchronize { errors << e }
          end
        end
      end

      threads.each(&:join)

      assert_empty errors, "Class introspection should be thread-safe"
      assert_equal 2000, results.size

      # All results should be identical
      expected = results.first
      results.each do |r|
        assert_equal expected[:positional], r[:positional]
        assert_equal expected[:keyword], r[:keyword]
        assert_equal expected[:required_positional], r[:required_positional]
        assert_equal expected[:required_keyword], r[:required_keyword]
      end
    end

    # Test that PartiallyApplied objects are thread-safe
    def test_partially_applied_thread_safe
      op_class = Class.new(ExplainableOperation) do
        param :a, Integer
        param :b, Integer
        param :c, Integer

        def perform
          a + b + c
        end
      end

      # Create a shared PartiallyApplied object
      partial = op_class.with(a: 1)

      results = []
      errors = []
      mutex = Mutex.new

      # Multiple threads completing the partial application differently
      threads = 20.times.map do |t|
        Thread.new do
          50.times do |i|
            # Each thread uses different values for b and c
            prepared = partial.with(b: t, c: i)
            result = prepared.call
            expected = 1 + t + i

            if result == expected
              mutex.synchronize { results << result }
            else
              mutex.synchronize do
                errors << {thread: t, iter: i, expected: expected, got: result}
              end
            end
          rescue => e
            mutex.synchronize { errors << {thread: t, iter: i, error: e} }
          end
        end
      end

      threads.each(&:join)

      assert_empty errors, "PartiallyApplied should be thread-safe: #{errors.first(5).inspect}"
      assert_equal 1000, results.size
    end

    # Test that operation chaining is thread-safe
    def test_chained_operations_thread_safe
      # Chain operations use positional Hash params and return Success with hash
      op1 = Class.new(::TypedOperation::Base) do
        include Dry::Monads[:result]

        positional_param :context, Hash

        def perform
          Success({value: context[:value] * 2})
        end
      end

      op2 = Class.new(::TypedOperation::Base) do
        include Dry::Monads[:result]

        positional_param :context, Hash

        def perform
          Success({result: context[:value] + 10})
        end
      end

      # Create a shared chain
      chain = op1.then(op2)

      results = []
      errors = []
      mutex = Mutex.new

      threads = 20.times.map do |t|
        Thread.new do
          50.times do |i|
            input = t * 100 + i
            result = chain.call({value: input})
            expected = (input * 2) + 10

            if result.success? && result.value![:result] == expected
              mutex.synchronize { results << result.value! }
            else
              mutex.synchronize do
                errors << {thread: t, input: input, expected: expected, got: result}
              end
            end
          rescue => e
            mutex.synchronize { errors << {thread: t, iter: i, error: e} }
          end
        end
      end

      threads.each(&:join)

      assert_empty errors, "Chained operations should be thread-safe: #{errors.first(5).inspect}"
      assert_equal 1000, results.size
    end

    # Test that Pipeline is thread-safe
    def test_pipeline_thread_safe
      # Pipeline operations receive their input as the result from prior step
      op1 = Class.new(::TypedOperation::Base) do
        include Dry::Monads[:result]

        param :value, Integer

        def perform
          Success({value: value * 2})
        end
      end

      op2 = Class.new(::TypedOperation::Base) do
        include Dry::Monads[:result]

        positional_param :context, Hash  # Receives hash from prior step

        def perform
          Success({result: context[:value] + 100})
        end
      end

      # Create a shared pipeline
      pipeline = TypedOperation::Pipeline.build do
        step :double, op1
        step :add, op2
      end

      results = []
      errors = []
      mutex = Mutex.new

      threads = 20.times.map do |t|
        Thread.new do
          50.times do |i|
            input = t * 100 + i
            result = pipeline.call(value: input)
            expected = (input * 2) + 100

            if result.success? && result.value![:result] == expected
              mutex.synchronize { results << result.value! }
            else
              mutex.synchronize do
                errors << {thread: t, input: input, expected: expected, got: result}
              end
            end
          rescue => e
            mutex.synchronize { errors << {thread: t, iter: i, error: e} }
          end
        end
      end

      threads.each(&:join)

      assert_empty errors, "Pipeline should be thread-safe: #{errors.first(5).inspect}"
      assert_equal 1000, results.size
    end

    # Test currying is thread-safe
    def test_curried_operation_thread_safe
      op = Class.new(ExplainableOperation) do
        positional_param :a, Integer
        positional_param :b, Integer

        def perform
          a + b
        end
      end

      # Create a shared curried operation
      curried = op.curry

      results = []
      errors = []
      mutex = Mutex.new

      threads = 10.times.map do |t|
        Thread.new do
          20.times do |i|
            # Each thread applies different values
            # Curry applies positional args one at a time
            result = curried.call(t).call(i)
            expected = t + i

            if result == expected
              mutex.synchronize { results << result }
            else
              mutex.synchronize do
                errors << {thread: t, iter: i, expected: expected, got: result}
              end
            end
          rescue => e
            mutex.synchronize { errors << {thread: t, iter: i, error: e} }
          end
        end
      end

      threads.each(&:join)

      assert_empty errors, "Curried operations should be thread-safe: #{errors.first(5).inspect}"
      assert_equal 200, results.size
    end

    # Test that ImmutableBase is thread-safe
    def test_immutable_base_thread_safe
      op = Class.new(::TypedOperation::ImmutableBase) do
        param :value, Integer
        param :multiplier, Integer, default: 2

        def perform
          value * multiplier
        end
      end

      results = []
      errors = []
      mutex = Mutex.new

      threads = 20.times.map do |t|
        Thread.new do
          50.times do |i|
            input = t * 100 + i
            result = op.call(value: input)
            expected = input * 2

            if result == expected
              mutex.synchronize { results << result }
            else
              mutex.synchronize do
                errors << {thread: t, input: input, expected: expected, got: result}
              end
            end
          rescue => e
            mutex.synchronize { errors << {thread: t, iter: i, error: e} }
          end
        end
      end

      threads.each(&:join)

      assert_empty errors, "ImmutableBase should be thread-safe: #{errors.first(5).inspect}"
      assert_equal 1000, results.size
    end
  end
end
