# frozen_string_literal: true

module TypedOperation
  module Operations
    module Executable
      def call
        execute_operation
      end

      def execute_operation
        before_execute_operation
        retval = perform
        after_execute_operation(retval)
      end

      def before_execute_operation
        # noop
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
