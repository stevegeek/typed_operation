# frozen_string_literal: true

require "test_helper"

class PipelineTest < Minitest::Test
  include Dry::Monads[:result]

  def setup
    TypedOperation.configure { |c| c.result_adapter = :dry_monads }
  end

  def teardown
    TypedOperation.reset_configuration!
  end

  class ValidateInputOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      input = context[:input]
      return Failure([:invalid_input, "Input too short"]) if input.length < 3

      Success({input: input})
    end
  end

  class TransformOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      Success({output: context[:input].upcase})
    end
  end

  class SaveOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      record = {id: rand(1000), value: context[:output], saved_at: Time.now}
      Success({record: record})
    end
  end

  class NotifyOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      Success(context[:record].merge(notified: true))
    end
  end

  def test_basic_pipeline_creation
    pipeline = TypedOperation::Pipeline.build do
      step ValidateInputOperation
      step TransformOperation
      step SaveOperation
    end

    result = pipeline.call({input: "test"})

    assert result.success?
    record = result.value![:record]
    assert record[:id]
    assert_equal "TEST", record[:value]
  end

  def test_pipeline_stops_on_failure
    pipeline = TypedOperation::Pipeline.build do
      step ValidateInputOperation
      step TransformOperation
      step SaveOperation
    end

    result = pipeline.call({input: "ab"})

    assert result.failure?
    code, message = result.failure
    assert_equal :invalid_input, code
    assert_equal "Input too short", message
  end

  def test_pipeline_with_named_steps
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateInputOperation
      step :transform, TransformOperation
      step :save, SaveOperation
      step :notify, NotifyOperation
    end

    result = pipeline.call({input: "test"})

    assert result.success?
    assert result.value![:notified]
  end

  def test_pipeline_can_be_introspected
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateInputOperation
      step :transform, TransformOperation
      step :save, SaveOperation
    end

    assert_respond_to pipeline, :steps
    assert_equal 3, pipeline.steps.size

    step_names = pipeline.steps.map { |s| s[:name] }
    assert_equal [:validate, :transform, :save], step_names
  end

  def test_pipeline_with_conditional_step
    pipeline = TypedOperation::Pipeline.build do
      step ValidateInputOperation
      step TransformOperation
      step SaveOperation
      step NotifyOperation, if: ->(result) { result[:record] && result[:record][:value]&.length.to_i > 0 }
    end

    result_with_notify = pipeline.call({input: "test"})
    assert result_with_notify.success?
    assert result_with_notify.value![:notified]
  end

  def test_pipeline_with_error_handler
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateInputOperation
      step :transform, TransformOperation
      step :save, SaveOperation

      on_failure do |error, step_name|
        Dry::Monads::Failure([:pipeline_error, "Failed at step #{step_name}: #{error}"])
      end
    end

    result = pipeline.call({input: "ab"})

    assert result.failure?
    code, message = result.failure
    assert_equal :pipeline_error, code
    assert_match(/Failed at step/, message)
    assert_match(/validate/, message)
  end

  def test_pipelines_can_be_composed
    validation_pipeline = TypedOperation::Pipeline.build do
      step ValidateInputOperation
      step TransformOperation
    end

    persistence_pipeline = TypedOperation::Pipeline.build do
      step SaveOperation
      step NotifyOperation
    end

    full_pipeline = validation_pipeline.compose(persistence_pipeline)

    result = full_pipeline.call({input: "test"})

    assert result.success?
    assert result.value![:notified]
  end

  def test_pipelines_can_be_composed_with_plus
    validation_pipeline = TypedOperation::Pipeline.build do
      step ValidateInputOperation
      step TransformOperation
    end

    persistence_pipeline = TypedOperation::Pipeline.build do
      step SaveOperation
      step NotifyOperation
    end

    full_pipeline = validation_pipeline + persistence_pipeline

    result = full_pipeline.call({input: "test"})

    assert result.success?
    assert result.value![:notified]
    assert_kind_of TypedOperation::Pipeline, full_pipeline
  end

  def test_pipeline_behaves_like_operation
    pipeline = TypedOperation::Pipeline.build do
      step ValidateInputOperation
      step TransformOperation
    end

    assert_respond_to pipeline, :call

    extended_pipeline = pipeline.append(SaveOperation)

    result = extended_pipeline.call({input: "test"})
    assert result.success?
    assert_kind_of TypedOperation::Pipeline, extended_pipeline
  end

  def test_pipeline_can_be_used_in_chains_via_to_chain
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateInputOperation
      step :transform, TransformOperation
    end

    chain = pipeline.to_chain
      .then(SaveOperation)
      .then(NotifyOperation)

    result = chain.call({input: "test"})

    assert result.success?
    assert result.value![:notified]
  end

  def test_pipeline_append_with_options
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateInputOperation
    end

    extended = pipeline.append(
      NotifyOperation,
      name: :notify,
      if: ->(ctx) { ctx[:output] }
    )

    assert_equal 2, extended.steps.size
    assert_equal :notify, extended.steps.last[:name]
    refute_nil extended.steps.last[:condition]
  end

  def test_complete_data_processing_pipeline
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateInputOperation
      step :transform, TransformOperation
      step :save, SaveOperation
      step :notify, NotifyOperation, if: ->(result) { result[:record].is_a?(Hash) }

      on_failure do |error, step_name|
        Dry::Monads::Failure([:pipeline_failed, {step: step_name, error: error}])
      end
    end

    result = pipeline.call({input: "hello world"})
    assert result.success?
    assert_equal "HELLO WORLD", result.value![:value]
    assert result.value![:notified]

    failure_result = pipeline.call({input: "ab"})
    assert failure_result.failure?
    code, details = failure_result.failure
    assert_equal :pipeline_failed, code
    assert_equal :validate, details[:step]
  end

  def test_pipeline_with_unnamed_steps
    pipeline = TypedOperation::Pipeline.build do
      step ValidateInputOperation
      step TransformOperation
      step SaveOperation
    end

    result = pipeline.call({input: "test"})

    assert result.success?

    operations = pipeline.steps.map { |s| s[:operation] }
    assert_equal [ValidateInputOperation, TransformOperation, SaveOperation], operations
  end

  def test_pipeline_failure_includes_step_name
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateInputOperation
      step :transform, TransformOperation

      on_failure do |error, step_name|
        Dry::Monads::Failure([:step_failed, {step: step_name, original_error: error}])
      end
    end

    result = pipeline.call({input: "ab"})

    assert result.failure?
    code, details = result.failure
    assert_equal :step_failed, code
    assert_equal :validate, details[:step]
    assert details[:original_error]
  end

  def test_empty_pipeline_returns_input
    pipeline = TypedOperation::Pipeline.build do
    end

    result = pipeline.call({input: "test"})

    assert result.success?
    assert_equal "test", result.value![:input]
  end

  def test_single_step_pipeline
    pipeline = TypedOperation::Pipeline.build do
      step ValidateInputOperation
    end

    result = pipeline.call({input: "test"})

    assert result.success?
    assert_equal "test", result.value![:input]
  end

  def test_pipeline_with_context_object
    context_aware_op = Class.new(TypedOperation::Base) do
      include Dry::Monads[:result]

      positional_param :ctx, TypedOperation::Context

      def perform
        Success(TypedOperation::Context.new(
          input: ctx.input,
          processed: true
        ))
      end
    end

    pipeline = TypedOperation::Pipeline.build do
      step context_aware_op
    end

    ctx = TypedOperation::Context.new(input: "hello")
    result = pipeline.call(ctx)

    assert result.success?
    value = result.value!
    assert value[:processed]
  end

  def test_pipeline_with_context_dot_access
    ctx = TypedOperation::Context.new(input: "test", user_id: 123)

    assert_equal "test", ctx.input
    assert_equal 123, ctx.user_id

    ctx.validated = true
    assert ctx.validated?
  end

  class KwargsValidateOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :input, String

    def perform
      return Failure([:invalid_input, "Input too short"]) if input.length < 3
      Success(input: input, validated: true)
    end
  end

  class KwargsTransformOperation < TypedOperation::Base
    include Dry::Monads[:result]
    include Literal::Types

    param :input, String
    param :validated, _Boolean, default: false

    def perform
      Success(output: input.upcase, validated: validated)
    end
  end

  def test_pipeline_with_kwargs_operations
    pipeline = TypedOperation::Pipeline.build do
      step :validate, KwargsValidateOperation
      step :transform, KwargsTransformOperation
    end

    result = pipeline.call(input: "test")

    assert result.success?
    assert_equal "TEST", result.value![:output]
    assert result.value![:validated]
  end

  def test_pipeline_with_positional_operation_receiving_hash
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateInputOperation
      step :transform, TransformOperation
    end

    result = pipeline.call({input: "test"})

    assert result.success?
    assert_equal "TEST", result.value![:output]
  end

  class PositionalConsumerOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :data, Hash

    def perform
      Success(consumed: data.keys.sort, original_data: data)
    end
  end

  def test_pipeline_kwargs_then_positional_operation
    pipeline = TypedOperation::Pipeline.build do
      step :validate, KwargsValidateOperation
      step :consume, PositionalConsumerOperation
    end

    result = pipeline.call(input: "test")

    assert result.success?, "Expected success but got: #{result.inspect}"
    assert_includes result.value![:consumed], :input
    assert_includes result.value![:consumed], :validated
  end
end
