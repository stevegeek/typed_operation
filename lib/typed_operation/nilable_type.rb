# frozen_string_literal: true

require "literal"

module TypedOperation
  class NilableType < Literal::Union
    def initialize(*types)
      @types = types + [NilClass]
    end
  end
end
