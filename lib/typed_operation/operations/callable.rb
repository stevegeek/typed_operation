# frozen_string_literal: true

module TypedOperation
  module Operations
    # Provides class-level and instance-level call methods for operations,
    # enabling functional-style invocation and proc conversion.
    module Callable
      def self.included(base)
        base.extend(CallableMethods)
      end

      # Methods available at both class and instance level for calling operations.
      module CallableMethods
        def call(...)
          new(...).call
        end

        def to_proc
          method(:call).to_proc
        end
      end

      include CallableMethods
    end
  end
end
