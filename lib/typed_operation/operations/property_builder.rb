# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Operations
    # Builds typed properties for operations, handling optional parameters,
    # defaults, and type conversions with Literal types.
    #
    # @rbs generic D -- type of default value
    class PropertyBuilder
      include Literal::Types

      # @rbs @typed_operation: untyped
      # @rbs @name: Symbol
      # @rbs @signature: untyped
      # @rbs @optional: bool?
      # @rbs @positional: bool?
      # @rbs @reader: Symbol
      # @rbs @has_default: bool
      # @rbs @default: untyped

      #: (singleton(Base) | singleton(ImmutableBase), Symbol, Literal::Types::_Matchable, Hash[Symbol, untyped]) -> void
      def initialize(typed_operation, parameter_name, type_signature, options)
        @typed_operation = typed_operation
        @name = parameter_name
        @signature = type_signature
        @optional = options[:optional]
        @positional = options[:positional]
        @reader = options[:reader] || :public
        @has_default = options.key?(:default)
        @default = options[:default]

        prepare_type_signature
      end

      #: () { (untyped) -> untyped } -> void
      #: () -> void
      def define(&converter)
        coerce_by = if type_nilable? && converter
          ->(value) { (value == Literal::Undefined || value.nil?) ? value : converter.call(value) }
        else
          converter
        end
        @typed_operation.prop(
          @name,
          @signature,
          @positional ? :positional : :keyword,
          default: resolved_default,
          reader: @reader,
          &coerce_by
        )
      end

      private

      #: () -> void
      def prepare_type_signature
        @signature = Literal::Types::NilableType.new(@signature) if needs_to_be_nilable?
        union_with_nil_to_support_nil_default
        validate_positional_order! if @positional
      end

      #: () -> bool
      def needs_to_be_nilable?
        !!(@optional && !type_nilable?)
      end

      #: () -> bool
      def type_nilable?
        @signature.is_a?(Literal::Types::NilableType)
      end

      #: () -> void
      def union_with_nil_to_support_nil_default
        @signature = _Union(@signature, NilClass) if has_nil_default?
      end

      #: () -> void
      def validate_positional_order!
        unless type_nilable? || @typed_operation.optional_positional_parameters.empty?
          raise ParameterError, "Cannot define required positional parameter '#{@name}' after optional positional parameters"
        end
      end

      #: () -> bool
      def default_provided?
        @has_default
      end

      #: () -> bool
      def has_nil_default?
        default_provided? && @default.nil?
      end

      #: () -> (D | Proc | nil)
      def resolved_default
        if has_nil_default? || (type_nilable? && !default_provided?)
          -> {} # 'nil' as in a proc that returns nil
        else
          @default
        end
      end
    end
  end
end
