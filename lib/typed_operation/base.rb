# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Mutable base class for operations, built on Literal::Struct.
  # Use this when operation state can be modified after initialization.
  class Base < Literal::Struct
    extend Operations::Introspection
    extend Operations::Parameters
    extend Operations::PartialApplication
    extend Operations::Composition

    include Operations::Lifecycle
    include Operations::Executable
  end
end
