# frozen_string_literal: true

require "literal"

module TypedOperation
  class Base < Literal::Data
    class << self
      def call(...)
        new(...).call
      end

      def curry(...)
        PartiallyApplied.new(self, ...).curry
      end
      alias_method :[], :curry
      alias_method :with, :curry

      def to_proc
        method(:call).to_proc
      end

      def operation_key
        name.underscore.to_sym
      end

      # Parameter for positional argument
      def positional(name, signature = :any, **options, &converter)
        param(name, signature, **options.merge(positional: true), &converter)
      end

      # Parameter for a keyword or named argument
      def named(name, signature = :any, **options, &converter)
        param(name, signature, **options.merge(positional: false), &converter)
      end

      # Parameter for keyword argument, or a positional argument if you use positional: true
      # Required, but you can set a default or use allow_nil: true if you want optional
      def param(name, signature = :any, **options, &converter)
        define_literal_attribute(name, signature, options, &converter)
      end

      # Introspection methods

      def positional_parameters
        literal_attributes.filter_map { |name, attribute| name if attribute.positional? }
      end

      def keyword_parameters
        literal_attributes.filter_map { |name, attribute| name unless attribute.positional? }
      end

      def required_positional_parameters
        required_parameters.filter_map { |name, attribute| name if attribute.positional? }
      end

      def required_keyword_parameters
        required_parameters.filter_map { |name, attribute| name unless attribute.positional? }
      end

      private

      def define_literal_attribute(name, signature, options, &converter)
        positional = options[:positional]
        reader = options[:reader] || :public
        type_signature = prepare_signature(signature, options)
        default_val_or_proc = prepare_default_value_for(name, options)

        attribute(name, type_signature, default: default_val_or_proc, positional: positional, reader: reader, &converter)
      end

      def prepare_signature(signature, options)
        allows_nil?(options) ? Literal::Union.new(signature, NilClass) : signature
      end

      def prepare_default_value_for(name, options)
        if !options[:default].nil?
          options[:default]
        elsif allows_nil?(options)
          -> {}
        end
      end

      def allows_nil?(options)
        options[:allow_nil] == true || (options.key?(:default) && options[:default].nil?)
      end

      def required_parameters
        @required_parameters ||= literal_attributes.filter do |name, attribute|
          required_attribute?(attribute)
        end
      end

      def required_attribute?(attribute)
        attribute.default.nil?
      end
    end

    def after_initialization
      prepare if respond_to?(:prepare)
    end

    def call
      raise InvalidOperationError, "You must implement #call"
    end

    def to_proc
      method(:call).to_proc
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
