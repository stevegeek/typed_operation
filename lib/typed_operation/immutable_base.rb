# frozen_string_literal: true

require "literal"

module TypedOperation
  class ImmutableBase < Literal::Data
    extend Operations::Introspection
    extend Operations::Parameters
    extend Operations::PartialApplication

    include Operations::Callable
    include Operations::Lifecycle
    include Operations::Deconstruct
  end
end
