# frozen_string_literal: true

module TypedOperation
  module Operations
    # Method to define parameters for your operation.
    module Parameters
      # Parameter for keyword argument, or a positional argument if you use positional: true
      # Required, but you can set a default or use optional: true if you want optional
      def param(name, signature = :any, **options, &converter)
        AttributeBuilder.new(self, name, signature, options).define(&converter)
      end

      # Alternative DSL

      # Parameter for positional argument
      def positional_param(name, signature = :any, **options, &converter)
        param(name, signature, **options.merge(positional: true), &converter)
      end

      # Parameter for a keyword or named argument
      def named_param(name, signature = :any, **options, &converter)
        param(name, signature, **options.merge(positional: false), &converter)
      end

      # Wrap a type signature in a NilableType meaning it is optional to TypedOperation
      def optional(type_signature)
        Literal::Types::NilableType.new(type_signature)
      end
    end
  end
end
