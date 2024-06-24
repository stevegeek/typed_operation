# frozen_string_literal: true

module TypedOperation
  class Base < Literal::Struct
    extend Operations::Introspection
    extend Operations::Parameters
    extend Operations::PartialApplication

    include Operations::Lifecycle
    include Operations::Callable
    include Operations::Executable
  end
end
