# frozen_string_literal: true

module TypedOperation
  module Operations
    # Defines the execution lifecycle for operations with before/after hooks.
    # Operations must implement #perform to define their core logic.
    module Executable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def call(...) = new(...).call

        def to_proc = method(:call).to_proc
      end

      def call
        execute_operation
      end

      def to_proc = method(:call).to_proc

      def execute_operation
        before_execute_operation
        retval = perform
        after_execute_operation(retval)
      end

      def before_execute_operation
      end

      def after_execute_operation(retval)
        retval
      end

      def perform
        raise InvalidOperationError, "Operation #{self.class} does not implement #perform"
      end
    end
  end
end
