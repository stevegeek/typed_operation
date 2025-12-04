# frozen_string_literal: true

module TypedOperation
  # Immutable base class for operations, built on Literal::Data.
  # Use this when operation state should not be modified after initialization.
  class ImmutableBase < Literal::Data
    extend Operations::Introspection
    extend Operations::Parameters
    extend Operations::PartialApplication
    extend Operations::Composition

    include Operations::Lifecycle
    include Operations::Executable
  end
end
