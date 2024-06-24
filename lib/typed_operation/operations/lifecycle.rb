# frozen_string_literal: true

module TypedOperation
  module Operations
    module Lifecycle
      # This is called by Literal on initialization of underlying Struct/Data
      def after_initialize
        prepare if respond_to?(:prepare)
      end
    end
  end
end
