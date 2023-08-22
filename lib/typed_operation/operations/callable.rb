# frozen_string_literal: true

module TypedOperation
  module Operations
    module Callable
      def self.included(base)
        base.extend(CallableMethods)
      end

      module CallableMethods
        def call(...)
          new(...).call
        end

        def to_proc
          method(:call).to_proc
        end
      end

      include CallableMethods

      def call
        raise InvalidOperationError, "You must implement #call"
      end
    end
  end
end
