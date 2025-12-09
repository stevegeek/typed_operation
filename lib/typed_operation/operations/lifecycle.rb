# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Operations
    # Hooks into Literal's initialization lifecycle to call #prepare if defined.
    module Lifecycle
      # This is called by Literal on initialization of underlying Struct/Data.
      #: () -> void
      def after_initialize
        prepare if respond_to?(:prepare)
      end
    end
  end
end
