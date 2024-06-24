# frozen_string_literal: true

module TypedOperation
  module Operations
    # Introspection methods
    module Introspection
      def positional_parameters
        literal_properties.filter_map { |property| property.name if property.positional? }
      end

      def keyword_parameters
        literal_properties.filter_map { |property| property.name if property.keyword? }
      end

      def required_parameters
        literal_properties.filter { |property| property.required? }
      end

      def required_positional_parameters
        required_parameters.filter_map { |property| property.name if property.positional? }
      end

      def required_keyword_parameters
        required_parameters.filter_map { |property| property.name if property.keyword? }
      end

      def optional_positional_parameters
        positional_parameters - required_positional_parameters
      end

      def optional_keyword_parameters
        keyword_parameters - required_keyword_parameters
      end
    end
  end
end
