# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Instrumentation
    # Represents a single operation execution trace with timing and result data.
    # Supports nested traces for operations that call other operations.
    class Trace
      attr_reader :operation_class #: untyped
      attr_reader :params #: Hash[Symbol, untyped]
      attr_reader :start_time #: Float
      attr_reader :children #: Array[Trace]
      attr_accessor :end_time #: Float?
      attr_accessor :result #: untyped
      attr_accessor :exception #: Exception?
      attr_accessor :pass_mode #: Symbol?
      attr_accessor :extracted_params #: Array[Symbol]?
      attr_accessor :fallback_used #: bool

      #: (operation_class: untyped, ?params: Hash[Symbol, untyped]) -> void
      def initialize(operation_class:, params: {})
        @operation_class = operation_class
        @params = params
        @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @end_time = nil
        @result = nil
        @exception = nil
        @children = []
        @pass_mode = nil
        @extracted_params = nil
        @fallback_used = false
      end

      #: (?result: untyped, ?exception: Exception?) -> self
      def finish!(result: nil, exception: nil)
        @end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @result = result
        @exception = exception
        self
      end

      #: () -> (Float | Integer | nil)
      def duration_ms
        return nil unless end_time
        ((end_time - start_time) * 1000).round(2)
      end

      #: () -> bool
      def success?
        return false if exception
        return result.success? if result.respond_to?(:success?)
        true
      end

      #: () -> bool
      def failure?
        !success?
      end

      #: (Trace) -> void
      def add_child(trace)
        @children << trace
      end

      #: () -> String
      def operation_name
        operation_class.name || operation_class.to_s
      end
    end
  end
end
