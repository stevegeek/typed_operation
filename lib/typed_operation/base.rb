# frozen_string_literal: true

require "literal"

module TypedOperation
  class Base < Literal::Struct
    extend Operations::Introspection
    extend Operations::Parameters
    extend Operations::PartialApplication

    include Operations::Callable
    include Operations::Lifecycle
    include Operations::Deconstruct

    def with(...)
      # copy to new operation with new attrs
      self.class.new(**attributes.merge(...))
    end
  end
end
