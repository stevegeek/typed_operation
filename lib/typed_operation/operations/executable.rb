# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Operations
    # Defines the execution lifecycle for operations with before/after hooks.
    # Operations must implement #perform to define their core logic.
    module Executable
      #: (Module) -> void
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # @rbs!
        #   def new: (*untyped, **untyped) -> untyped

        #: (*untyped, **untyped) -> untyped
        def call(...) = new(...).call

        #: () -> Proc
        def to_proc = method(:call).to_proc
      end

      #: () -> untyped
      def call
        execute_operation
      end

      #: () -> Proc
      def to_proc = method(:call).to_proc

      #: () -> untyped
      def execute_operation
        before_execute_operation
        retval = perform
        after_execute_operation(retval)
      end

      #: () -> void
      def before_execute_operation
      end

      #: (untyped) -> untyped
      def after_execute_operation(retval)
        retval
      end

      #: () -> untyped
      def perform
        raise InvalidOperationError, "Operation #{self.class} does not implement #perform"
      end
    end
  end
end
