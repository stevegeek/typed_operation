# frozen_string_literal: true

module TypedOperation
  module Operations
    # Introspection methods
    module Introspection
      def positional_parameters
        literal_attributes.filter_map { |name, attribute| name if attribute.positional? }
      end

      def keyword_parameters
        literal_attributes.filter_map { |name, attribute| name unless attribute.positional? }
      end

      def required_parameters
        literal_attributes.filter do |name, attribute|
          attribute.default.nil? # Any optional parameters will have a default value/proc in their Literal::Attribute
        end
      end

      def required_positional_parameters
        required_parameters.filter_map { |name, attribute| name if attribute.positional? }
      end

      def required_keyword_parameters
        required_parameters.filter_map { |name, attribute| name unless attribute.positional? }
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
