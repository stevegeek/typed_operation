# rbs_inline: enabled
# frozen_string_literal: true

# Type tests for PropertyBuilder - checked by Steep, not run as tests
# These examples verify the RBS type signatures are correct

require_relative "../../lib/typed_operation"

module TypedOperation
  module Operations
    # Test: PropertyBuilder with String default
    class TestOperation < TypedOperation::Base
      def perform
      end
    end

    # Basic construction with class type matcher
    builder_with_class = PropertyBuilder.new(
      TestOperation,
      :name,
      String,
      {}
    )
    builder_with_class.define

    # Construction with Literal type
    builder_with_literal_type = PropertyBuilder.new(
      TestOperation,
      :active,
      Literal::Types::BooleanType.new,
      {}
    )
    builder_with_literal_type.define

    # Construction with Module as type matcher
    builder_with_module = PropertyBuilder.new(
      TestOperation,
      :enumerable,
      Enumerable,
      {}
    )
    builder_with_module.define

    # With options hash
    builder_with_options = PropertyBuilder.new(
      TestOperation,
      :role,
      String,
      {default: "user", optional: false, positional: false, reader: :public}
    )
    builder_with_options.define

    # With converter block
    builder_with_converter = PropertyBuilder.new(
      TestOperation,
      :count,
      Integer,
      {}
    )
    builder_with_converter.define { |v| v.to_i }

    # With nil default (tests generic D = nil case)
    builder_with_nil_default = PropertyBuilder.new(
      TestOperation,
      :optional_name,
      String,
      {default: nil, optional: true}
    )
    builder_with_nil_default.define

    # With Proc default (tests generic D = Proc case)
    builder_with_proc_default = PropertyBuilder.new(
      TestOperation,
      :timestamp,
      Time,
      {default: -> { Time.now }}
    )
    builder_with_proc_default.define
  end
end
