# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Include this module in your operation base class to enable the `.explain` method
  # for runtime tracing and debugging.
  module Explainable
    #: (Module) -> void
    def self.included(base)
      base.extend(Instrumentation::Explainable)
      base.prepend(Instrumentation::Traceable)
    end
  end
end
