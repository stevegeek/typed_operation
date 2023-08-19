# frozen_string_literal: true

module TypedOperation
  class PartiallyApplied
    def initialize(operation_class, *positional_args, **keyword_args)
      @operation_class = operation_class
      @positional_args = positional_args
      @keyword_args = keyword_args
    end

    def curry(*positional, **keyword)
      all_positional = @positional_args + positional
      all_kw_args = @keyword_args.merge(keyword)

      validate_positional_arg_count!(all_positional.size)

      if partially_applied?(all_positional, all_kw_args)
        PartiallyApplied.new(operation_class, *all_positional, **all_kw_args)
      else
        Prepared.new(operation_class, *all_positional, **all_kw_args)
      end
    end
    alias_method :[], :curry
    alias_method :with, :curry

    def call(...)
      prepared = curry(...)
      return prepared.operation.call if prepared.is_a?(Prepared)
      raise MissingParameterError, "Cannot call PartiallyApplied operation #{operation_class.name} (key: #{operation_class.operation_key}), are you expecting it to be Prepared?"
    end

    def operation
      raise MissingParameterError, "Cannot instantiate Operation #{operation_class.name} (key: #{operation_class.operation_key}), as it is only partially applied."
    end

    def to_proc
      method(:call).to_proc
    end

    def deconstruct
      @positional_args + @keyword_args.values
    end

    def deconstruct_keys(keys)
      h = @keyword_args.dup
      @positional_args.each_with_index { |v, i| h[positional_parameters[i]] = v }
      keys ? h.slice(*keys) : h
    end

    private

    attr_reader :operation_class

    def required_positional_parameters
      @required_positional_parameters ||= operation_class.required_positional_parameters
    end

    def required_keyword_parameters
      @required_keyword_parameters ||= operation_class.required_keyword_parameters
    end

    def positional_parameters
      @positional_parameters ||= operation_class.positional_parameters
    end

    def validate_positional_arg_count!(count)
      if count > positional_parameters.size
        raise ArgumentError, "Too many positional arguments provided for #{operation_class.name} (key: #{operation_class.operation_key})"
      end
    end

    def partially_applied?(all_positional, all_kw_args)
      missing_positional = required_positional_parameters.size - all_positional.size
      missing_keys = required_keyword_parameters - all_kw_args.keys

      missing_positional > 0 || missing_keys.size > 0
    end
  end
end
