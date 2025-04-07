# frozen_string_literal: true

module TypedOperation
  module Operations
    # Method to define parameters for your operation.
    module Parameters
      # Override literal `prop` to prevent creating writers (Literal::Data does this by default)
      def prop(name, type, kind = :keyword, reader: :public, writer: :public, default: nil)
        if self < ImmutableBase
          super(name, type, kind, reader:, default:)
        else
          super(name, type, kind, reader:, writer: false, default:)
        end
      end

      # Parameter for keyword argument, or a positional argument if you use positional: true
      # Required, but you can set a default or use optional: true if you want optional
      def param(name, signature = :any, **options, &converter)
        PropertyBuilder.new(self, name, signature, options).define(&converter)
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
