# frozen_string_literal: true

require "literal"

module TypedOperation
  class Base < Literal::Data

    def after_initialization
      prepare if respond_to?(:prepare)
    end

    def deconstruct
      attributes.values
    end

    def deconstruct_keys(keys)
      h = attributes.to_h
      keys ? h.slice(*keys) : h
    end
  end
end
