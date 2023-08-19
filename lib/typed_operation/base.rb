# frozen_string_literal: true

require "literal"

module TypedOperation
  class Base < Literal::Data
    class << self
      def call(...)
        new(...).call
      end

      def curry(**args)
        PartiallyApplied.new(self, **args).curry
      end
      alias_method :[], :curry
      alias_method :with, :curry

      def to_proc
        method(:call).to_proc
      end

      def operation_key
        name.underscore.to_sym
      end

      # property are required by default, you can fall back to attribute or set allow_nil: true if you want optional
      def param(name, signature = :any, **options, &converter)
        attribute(
          name,
          prepare_signature(signature, options),
          default: prepare_default_value_for(name, options),
          &converter
        )
      end

      def required_params
        @required ||= @literal_attributes.filter_map do |name, attribute|
          name if required_attribute?(attribute)
        end
      end

      private

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

    def deconstruct_keys(_keys)
      attributes.to_h
    end
  end
end
