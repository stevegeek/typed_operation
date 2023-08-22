# frozen_string_literal: true

module TypedOperation
  module Operations
    module Deconstruct
      def deconstruct
        attributes.values
      end

      def deconstruct_keys(keys)
        h = attributes.to_h
        keys ? h.slice(*keys) : h
      end
    end
  end
end
