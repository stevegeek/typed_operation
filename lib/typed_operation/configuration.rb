# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Global configuration for TypedOperation.
  class Configuration
    # @rbs @result_adapter: (Result::Adapters::BuiltIn | Result::Adapters::DryMonads | untyped)?

    #: () -> void
    def initialize
      @result_adapter = nil
    end

    # Get the current result adapter. Defaults to BuiltIn.
    #: () -> (Result::Adapters::BuiltIn | Result::Adapters::DryMonads | untyped)
    def result_adapter
      @result_adapter ||= Result::Adapters::BuiltIn.new
    end

    # Set the result adapter.
    #: (:built_in | :dry_monads | untyped) -> void
    def result_adapter=(adapter)
      @result_adapter = case adapter
      when :built_in then Result::Adapters::BuiltIn.new
      when :dry_monads then Result::Adapters::DryMonads.new
      else adapter
      end
    end
  end

  class << self
    # @rbs @configuration: Configuration?

    # Get the global configuration instance.
    #: () -> Configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure TypedOperation with a block.
    #: () { (Configuration) -> void } -> void
    def configure
      yield(configuration)
    end

    # Reset configuration to defaults. Mainly for testing.
    #: () -> void
    def reset_configuration!
      @configuration = nil
    end
  end
end
