# frozen_string_literal: true

module TypedOperation
  module Operations
    class PropertyBuilder
      include Literal::Types

      def initialize(typed_operation, parameter_name, type_signature, options)
        @typed_operation = typed_operation
        @name = parameter_name
        @signature = type_signature
        @optional = options[:optional] # Wraps signature in NilableType
        @positional = options[:positional] # Changes kind to positional
        @reader = options[:reader] || :public
        @default_key = options.key?(:default)
        @default = options[:default]

        prepare_type_signature_for_literal
      end

      def define(&converter)
        # If nilable, then converter should not attempt to call the type converter block if the value is nil
        coerce_by = if type_nilable? && converter
          ->(v) { (v == Literal::Null || v.nil?) ? v : converter.call(v) }
        else
          converter
        end
        @typed_operation.prop(
          @name,
          @signature,
          @positional ? :positional : :keyword,
          default: default_value_for_literal,
          reader: @reader,
          &coerce_by
        )
      end

      private

      def prepare_type_signature_for_literal
        @signature = Literal::Types::NilableType.new(@signature) if needs_to_be_nilable?
        union_with_nil_to_support_nil_default
        validate_positional_order_params! if @positional
      end

      # If already wrapped in a Nilable then don't wrap again
      def needs_to_be_nilable?
        @optional && !type_nilable?
      end

      def type_nilable?
        @signature.is_a?(Literal::Types::NilableType)
      end

      def union_with_nil_to_support_nil_default
        @signature = _Union(@signature, NilClass) if has_default_value_nil?
      end

      def has_default_value_nil?
        default_provided? && @default.nil?
      end

      def validate_positional_order_params!
        # Optional ones can always be added after required ones, or before any others, but required ones must be first
        unless type_nilable? || @typed_operation.optional_positional_parameters.empty?
          raise ParameterError, "Cannot define required positional parameter '#{@name}' after optional positional parameters"
        end
      end

      def default_provided?
        @default_key
      end

      def default_value_for_literal
        if has_default_value_nil? || type_nilable?
          -> {}
        else
          @default
        end
      end
    end
  end
end
