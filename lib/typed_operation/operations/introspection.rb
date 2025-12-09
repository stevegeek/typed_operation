# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Operations
    # Introspection methods for querying operation parameters.
    module Introspection
      #: () -> Array[Symbol]
      def positional_parameters
        literal_properties.filter_map { |property| property.name if property.positional? }
      end

      #: () -> Array[Symbol]
      def keyword_parameters
        literal_properties.filter_map { |property| property.name if property.keyword? }
      end

      #: () -> Array[Literal::_Property]
      def required_parameters
        literal_properties.filter { |property| property.required? }
      end

      #: () -> Array[Symbol]
      def required_positional_parameters
        required_parameters.filter_map { |property| property.name if property.positional? }
      end

      #: () -> Array[Symbol]
      def required_keyword_parameters
        required_parameters.filter_map { |property| property.name if property.keyword? }
      end

      #: () -> Array[Symbol]
      def optional_positional_parameters
        positional_parameters - required_positional_parameters
      end

      #: () -> Array[Symbol]
      def optional_keyword_parameters
        keyword_parameters - required_keyword_parameters
      end
    end
  end
end
