# frozen_string_literal: true

require "dry/monads"
require "vident/typed/attributes"

module TypedOperation
  class Base
    include Dry::Monads[:result, :do]
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
      prepare_attributes(attributes)
      prepare if respond_to?(:prepare)
    end

    def call
      raise NotImplementedError, "You must implement #call"
    end

    def call!
      call.value!
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
