# frozen_string_literal: true

module TypedOperation
  class PartiallyApplied
    def initialize(operation, **applied_args)
      @operation = operation
      @applied_args = applied_args
    end

    def curry(**params)
      all_args = @applied_args.merge(params)
      # check if required attrs are in @applied_args
      required_keys = @operation.attribute_names.select do |name|
        meta = @operation.attribute_metadata(name)
        meta[:required] != false && !meta[:typed_attribute_options].key?(:default)
      end
      missing_keys = required_keys - all_args.keys

      if missing_keys.size > 0
        # Partially apply the arguments
        PartiallyApplied.new(@operation, **all_args)
      else
        Prepared.new(@operation, **all_args)
      end
    end
    alias_method :[], :curry
    alias_method :with, :curry

    def call(...)
      prepared = curry(...)
      return prepared.operation.call if prepared.is_a?(Prepared)
      raise TypedOperation::MissingParameterError, "Cannot call PartiallyApplied operation #{@operation.name} (key: #{@operation.operation_key}), are you expecting it to be Prepared?"
    end

    def deconstruct
      @applied_args.values
    end

    def deconstruct_keys(_keys)
      @applied_args.dup
    end
  end
end
