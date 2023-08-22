# frozen_string_literal: true

module TypedOperation
  module Operations
    module Lifecycle
      def after_initialization
        prepare if respond_to?(:prepare)
      end
    end
  end
end
