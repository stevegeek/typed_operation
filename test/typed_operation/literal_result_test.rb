# frozen_string_literal: true

require "test_helper"
require "stringio"

class LiteralResultTest < Minitest::Test
  AgeResult = Literal::Result(Hash, Symbol)

  class ValidateAgeOperation < TypedOperation::Base
    param :age, Integer

    def perform
      (age >= 18) ? AgeResult.success({age: age}) : AgeResult.failure(:too_young)
    end
  end

  class GreetOperation < TypedOperation::Base
    param :age, Integer

    def perform
      Literal::Result(Hash, Symbol).success({greeting: "Welcome, age #{age}"})
    end
  end

  class AddOperation < TypedOperation::Base
    include TypedOperation::Result::Mixin

    param :a, Integer
    param :b, Integer

    def perform
      Success({sum: a + b})
    end
  end

  class DoubleOperation < TypedOperation::Base
    include TypedOperation::Result::Mixin

    param :sum, Integer

    def perform
      Success({result: sum * 2})
    end
  end

  class ExplainableValidateAgeOperation < ValidateAgeOperation
    include TypedOperation::Explainable
  end

  def setup
    TypedOperation.reset_configuration!
    TypedOperation::Instrumentation.clear_trace!
  end

  def teardown
    TypedOperation.reset_configuration!
  end

  def test_configure_with_literal_symbol
    TypedOperation.configure { |c| c.result_adapter = :literal }

    assert_instance_of TypedOperation::Result::Adapters::Literal, TypedOperation.configuration.result_adapter
  end

  def test_literal_adapter_creates_success
    result = TypedOperation::Result::Adapters::Literal.new.success(42)

    assert_instance_of Literal::Success, result
    assert_equal 42, result.value!
  end

  def test_literal_adapter_creates_failure
    result = TypedOperation::Result::Adapters::Literal.new.failure(:error)

    assert_instance_of Literal::Failure, result
    assert_equal :error, result.error!
  end

  def test_literal_adapter_accepts_nil
    assert_nil TypedOperation::Result::Adapters::Literal.new.success(nil).value!
    assert_nil TypedOperation::Result::Adapters::Literal.new.failure(nil).error!
  end

  def test_literal_adapter_name
    assert_equal "Literal::Result", TypedOperation::Result::Adapters::Literal.new.name
  end

  def test_mixin_uses_literal_when_configured
    TypedOperation.configure { |c| c.result_adapter = :literal }

    result = AddOperation.then(DoubleOperation).call(a: 2, b: 3)

    assert_instance_of Literal::Success, result
    assert_equal 10, result.value![:result]
  end

  def test_wrap_reads_literal_failure
    wrapped = TypedOperation::Result.wrap(AgeResult.failure(:too_young))

    assert_instance_of TypedOperation::Result::LiteralWrapper, wrapped
    assert wrapped.failure?
    refute wrapped.success?
    assert wrapped.error?
    assert_equal :too_young, wrapped.error
  end

  def test_wrap_reads_literal_success
    result = AgeResult.success({age: 21})
    wrapped = TypedOperation::Result.wrap(result)

    assert wrapped.success?
    refute wrapped.error?
    assert_equal({age: 21}, wrapped.value!)
    assert_same result, wrapped.unwrap
  end

  def test_wrap_reads_built_in_failure
    result = TypedOperation::Result::Failure.new(:oops)
    wrapped = TypedOperation::Result.wrap(result)

    assert_instance_of TypedOperation::Result::Wrapper, wrapped
    assert wrapped.failure?
    assert wrapped.error?
    assert_equal :oops, wrapped.error
    assert_same result, wrapped.unwrap
  end

  def test_wrap_of_object_without_failure_has_no_error
    refute TypedOperation::Result.wrap(Object.new).error?
  end

  def test_then_chains_literal_results
    result = ValidateAgeOperation.then(GreetOperation).call(age: 21)

    assert result.success?
    assert_equal({age: 21, greeting: "Welcome, age 21"}, result.value!)
  end

  def test_then_short_circuits_on_literal_failure
    result = ValidateAgeOperation.then(GreetOperation).call(age: 16)

    assert result.failure?
    assert_equal :too_young, result.error!
  end

  def test_or_else_block_receives_literal_failure_error
    received = nil
    chain = ValidateAgeOperation.or_else do |error|
      received = error
      AgeResult.success({age: 0})
    end

    result = chain.call(age: 16)

    assert_equal :too_young, received
    assert_equal({age: 0}, result.value!)
  end

  def test_pipeline_on_failure_receives_literal_failure_error
    received = nil
    pipeline = TypedOperation::Pipeline.build do
      step :validate, ValidateAgeOperation
      step :greet, GreetOperation

      on_failure do |error, step_name|
        received = [error, step_name]
        AgeResult.failure(:rejected)
      end
    end

    result = pipeline.call(age: 16)

    assert_equal [:too_young, :validate], received
    assert_equal :rejected, result.error!
  end

  def test_pattern_matching_on_literal_results
    message = case ValidateAgeOperation.call(age: 16)
    in Literal::Success({age:}) then "ok #{age}"
    in Literal::Failure[reason] then "failed #{reason}"
    end

    assert_equal "failed too_young", message
  end

  def test_explain_shows_literal_failure_error
    output = StringIO.new
    TypedOperation::Instrumentation.with_output(output, color: false) do
      ExplainableValidateAgeOperation.explain(age: 16)
    end

    assert_includes output.string, "Failure: :too_young"
  end
end
