# frozen_string_literal: true

module TypedOperation
  class Base < Literal::Struct
    extend Operations::Introspection
    extend Operations::Parameters
    extend Operations::PartialApplication

    include Operations::Lifecycle
    include Operations::Callable
    include Operations::Deconstruct
    include Operations::Executable

    class << self
      def attribute(name, type, special = nil, reader: :public, writer: :public, positional: false, default: nil)
        super(name, type, special, reader:, writer: false, positional:, default:)
      end
    end

    def with(...)
      # copy to new operation with new attrs
      self.class.new(**attributes.merge(...))
    end
  end
end
