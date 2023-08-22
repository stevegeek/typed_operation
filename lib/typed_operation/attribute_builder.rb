# frozen_string_literal: true

require "literal"

module TypedOperation
  class AttributeBuilder
    def initialize(typed_operation, parameter_name, type_signature, options)
      @typed_operation = typed_operation
      @name = parameter_name
      @signature = type_signature
      @optional = options[:optional]
      @positional = options[:positional]
      @reader = options[:reader] || :public
      @default_key = options.key?(:default)
      @default = options[:default]

      prepare_type_signature_for_literal
    end

    def define(&converter)
      @typed_operation.attribute(
        @name,
        @signature,
        default: default_value_for_literal,
        positional: @positional,
        reader: @reader,
        &converter
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
      @signature = Literal::Union.new(@signature, NilClass) if has_default_value_nil?
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
