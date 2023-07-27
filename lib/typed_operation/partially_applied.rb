# frozen_string_literal: true

module TypedOperation
  class PartiallyApplied
    def initialize(operation_class, **applied_args)
      @operation_class = operation_class
      @applied_args = applied_args
    end

    def curry(**params)
      all_args = @applied_args.merge(params)
      # check if required attrs are in @applied_args
      required_keys = @operation_class.required_params
      missing_keys = required_keys - all_args.keys

      if missing_keys.size > 0
        # Partially apply the arguments
        PartiallyApplied.new(@operation_class, **all_args)
      else
        Prepared.new(@operation_class, **all_args)
      end
    end
    alias_method :[], :curry
    alias_method :with, :curry

    def call(...)
      prepared = curry(...)
      return prepared.operation.call if prepared.is_a?(Prepared)
      raise MissingParameterError, "Cannot call PartiallyApplied operation #{@operation_class.name} (key: #{@operation_class.operation_key}), are you expecting it to be Prepared?"
    end

    private

    attr_reader :operation_class
  end
end
