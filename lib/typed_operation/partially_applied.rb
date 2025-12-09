# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Represents an operation with some, but not all, required parameters provided.
  # Allows incrementally building operation arguments before execution.
  class PartiallyApplied
    include Operations::Composition

    # @rbs @operation_class: untyped
    # @rbs @positional_args: Array[untyped]
    # @rbs @keyword_args: Hash[Symbol, untyped]

    attr_reader :positional_args #: Array[untyped]
    attr_reader :keyword_args #: Hash[Symbol, untyped]
    attr_reader :operation_class #: untyped

    #: (untyped, *untyped, **untyped) -> void
    def initialize(operation_class, *positional_args, **keyword_args)
      @operation_class = operation_class
      @positional_args = positional_args
      @keyword_args = keyword_args
    end

    #: (*untyped, **untyped) -> (PartiallyApplied | Prepared)
    def with(*positional, **keyword)
      all_positional = positional_args + positional
      all_kw_args = keyword_args.merge(keyword)

      validate_positional_arg_count!(all_positional.size)

      if partially_applied?(all_positional, all_kw_args)
        PartiallyApplied.new(operation_class, *all_positional, **all_kw_args)
      else
        Prepared.new(operation_class, *all_positional, **all_kw_args)
      end
    end
    alias_method :[], :with

    #: () -> Curried
    def curry
      Curried.new(operation_class, self)
    end

    #: (*untyped, **untyped) -> untyped
    def call(...)
      prepared = with(...)
      return prepared.operation.call if prepared.is_a?(Prepared)
      raise MissingParameterError, "Cannot call PartiallyApplied operation #{operation_class.name}, are you expecting it to be Prepared?"
    end

    #: () -> untyped
    def operation
      raise MissingParameterError, "Cannot instantiate Operation #{operation_class.name}, as it is only partially applied."
    end

    #: () -> false
    def prepared?
      false
    end

    #: () -> Proc
    def to_proc
      method(:call).to_proc
    end

    #: () -> Array[untyped]
    def deconstruct
      positional_args + keyword_args.values
    end

    #: (Array[Symbol]?) -> Hash[Symbol, untyped]
    def deconstruct_keys(keys)
      hash = keyword_args.dup
      positional_args.each_with_index { |value, index| hash[positional_parameters[index]] = value }
      keys ? hash.slice(*keys) : hash
    end

    private

    #: () -> Array[Symbol]
    def required_positional_parameters
      @required_positional_parameters ||= operation_class.required_positional_parameters
    end

    #: () -> Array[Symbol]
    def required_keyword_parameters
      @required_keyword_parameters ||= operation_class.required_keyword_parameters
    end

    #: () -> Array[Symbol]
    def positional_parameters
      @positional_parameters ||= operation_class.positional_parameters
    end

    #: (Integer) -> void
    def validate_positional_arg_count!(count)
      if count > positional_parameters.size
        raise ArgumentError, "Too many positional arguments provided for #{operation_class.name}"
      end
    end

    #: (Array[untyped], Hash[Symbol, untyped]) -> bool
    def partially_applied?(all_positional, all_kw_args)
      missing_positional = required_positional_parameters.size - all_positional.size
      missing_keys = required_keyword_parameters - all_kw_args.keys

      missing_positional > 0 || missing_keys.size > 0
    end
  end
end
