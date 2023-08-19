# frozen_string_literal: true

require "literal"

module TypedOperation
  class Base < Literal::Data
    class << self
      def call(...)
        new(...).call
      end

      def with(...)
        PartiallyApplied.new(self, ...).with
      end
      alias_method :[], :with

      def curry
        Curried.new(self)
      end

      def to_proc
        method(:call).to_proc
      end

      # Method to define parameters for your operation.

      # Parameter for keyword argument, or a positional argument if you use positional: true
      # Required, but you can set a default or use optional: true if you want optional
      def param(name, signature = :any, **options, &converter)
        AttributeBuilder.new(self, name, signature, options).define(&converter)
      end

      # Alternative DSL

      # Parameter for positional argument
      def positional(name, signature = :any, **options, &converter)
        param(name, signature, **options.merge(positional: true), &converter)
      end

      # Parameter for a keyword or named argument
      def named(name, signature = :any, **options, &converter)
        param(name, signature, **options.merge(positional: false), &converter)
      end

      # Wrap a type signature in a NilableType meaning it is optional to TypedOperation
      def optional(type_signature)
        NilableType.new(type_signature)
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

      def optional_positional_parameters
        positional_parameters - required_positional_parameters
      end

      def optional_keyword_parameters
        keyword_parameters - required_keyword_parameters
      end

      private

      def required_parameters
        literal_attributes.filter do |name, attribute|
          attribute.default.nil? # Any optional parameters will have a default value/proc in their Literal::Attribute
        end
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
