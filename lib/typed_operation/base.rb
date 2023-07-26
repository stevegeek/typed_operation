# frozen_string_literal: true

require "vident/typed"
require "vident/typed/attributes"

module TypedOperation
  class Base
    include Vident::Typed::Attributes

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
        attribute(name, signature, **{allow_nil: false}.merge(options), &converter)
      end
    end

    def initialize(**attributes)
      begin
        prepare_attributes(attributes)
      rescue ::Dry::Struct::Error => e
        raise ParameterError, e.message
      end
      prepare if respond_to?(:prepare)
    end

    def call
      raise InvalidOperationError, "You must implement #call"
    end

    def to_proc
      method(:call).to_proc
    end

    private

    def operation_key
      self.class.operation_key
    end
  end
end
