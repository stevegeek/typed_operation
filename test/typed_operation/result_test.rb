# frozen_string_literal: true

require "test_helper"

class ResultTest < Minitest::Test
  def setup
    TypedOperation.reset_configuration!
  end

  def teardown
    TypedOperation.reset_configuration!
  end

  # --- Built-in Success ---

  def test_success_is_success
    result = TypedOperation::Result::Success.new(42)
    assert result.success?
    refute result.failure?
  end

  def test_success_value
    result = TypedOperation::Result::Success.new("hello")
    assert_equal "hello", result.value!
    assert_equal "hello", result.value
  end

  def test_success_failure_returns_nil
    result = TypedOperation::Result::Success.new(42)
    assert_nil result.failure
  end

  def test_success_is_frozen
    result = TypedOperation::Result::Success.new({a: 1})
    assert result.frozen?
  end

  def test_success_pattern_matching_deconstruct
    result = TypedOperation::Result::Success.new(42)

    case result
    in TypedOperation::Result::Success[value]
      assert_equal 42, value
    else
      flunk "Pattern matching failed"
    end
  end

  def test_success_pattern_matching_deconstruct_keys
    result = TypedOperation::Result::Success.new(42)

    case result
    in TypedOperation::Result::Success[value:]
      assert_equal 42, value
    else
      flunk "Pattern matching failed"
    end
  end

  # --- Built-in Failure ---

  def test_failure_is_failure
    result = TypedOperation::Result::Failure.new(:error)
    refute result.success?
    assert result.failure?
  end

  def test_failure_error
    result = TypedOperation::Result::Failure.new(:not_found)
    assert_equal :not_found, result.failure
    assert_equal :not_found, result.error
  end

  def test_failure_value_bang_raises
    result = TypedOperation::Result::Failure.new(:error)

    error = assert_raises(TypedOperation::Result::UnwrapError) do
      result.value!
    end
    assert_match(/Cannot unwrap Failure/, error.message)
  end

  def test_failure_is_frozen
    result = TypedOperation::Result::Failure.new(:error)
    assert result.frozen?
  end

  def test_failure_pattern_matching_deconstruct
    result = TypedOperation::Result::Failure.new(:not_found)

    case result
    in TypedOperation::Result::Failure[error]
      assert_equal :not_found, error
    else
      flunk "Pattern matching failed"
    end
  end

  def test_failure_pattern_matching_deconstruct_keys
    result = TypedOperation::Result::Failure.new(:not_found)

    case result
    in TypedOperation::Result::Failure[error:]
      assert_equal :not_found, error
    else
      flunk "Pattern matching failed"
    end
  end

  def test_failure_pattern_matching_with_failure_key
    result = TypedOperation::Result::Failure.new(:not_found)

    case result
    in TypedOperation::Result::Failure[failure:]
      assert_equal :not_found, failure
    else
      flunk "Pattern matching failed"
    end
  end

  # --- Configuration ---

  def test_default_adapter_is_built_in
    adapter = TypedOperation.configuration.result_adapter
    assert_instance_of TypedOperation::Result::Adapters::BuiltIn, adapter
  end

  def test_configure_with_built_in_symbol
    TypedOperation.configure do |config|
      config.result_adapter = :built_in
    end

    adapter = TypedOperation.configuration.result_adapter
    assert_instance_of TypedOperation::Result::Adapters::BuiltIn, adapter
  end

  def test_configure_with_dry_monads_symbol
    TypedOperation.configure do |config|
      config.result_adapter = :dry_monads
    end

    adapter = TypedOperation.configuration.result_adapter
    assert_instance_of TypedOperation::Result::Adapters::DryMonads, adapter
  end

  def test_reset_configuration
    TypedOperation.configure do |config|
      config.result_adapter = :dry_monads
    end

    TypedOperation.reset_configuration!

    adapter = TypedOperation.configuration.result_adapter
    assert_instance_of TypedOperation::Result::Adapters::BuiltIn, adapter
  end

  # --- Adapters ---

  def test_built_in_adapter_creates_success
    adapter = TypedOperation::Result::Adapters::BuiltIn.new
    result = adapter.success(42)

    assert_instance_of TypedOperation::Result::Success, result
    assert_equal 42, result.value!
  end

  def test_built_in_adapter_creates_failure
    adapter = TypedOperation::Result::Adapters::BuiltIn.new
    result = adapter.failure(:error)

    assert_instance_of TypedOperation::Result::Failure, result
    assert_equal :error, result.failure
  end

  def test_dry_monads_adapter_creates_success
    adapter = TypedOperation::Result::Adapters::DryMonads.new
    result = adapter.success(42)

    assert result.success?
    assert_equal 42, result.value!
    assert_match(/Success/, result.class.name)
  end

  def test_dry_monads_adapter_creates_failure
    adapter = TypedOperation::Result::Adapters::DryMonads.new
    result = adapter.failure(:error)

    assert result.failure?
    assert_equal :error, result.failure
    assert_match(/Failure/, result.class.name)
  end

  # --- Result::Mixin ---

  class MixinTest
    include TypedOperation::Result::Mixin

    def create_success(value)
      Success(value)
    end

    def create_failure(error)
      Failure(error)
    end
  end

  def test_mixin_success_with_built_in
    obj = MixinTest.new
    result = obj.create_success(42)

    assert_instance_of TypedOperation::Result::Success, result
    assert_equal 42, result.value!
  end

  def test_mixin_failure_with_built_in
    obj = MixinTest.new
    result = obj.create_failure(:error)

    assert_instance_of TypedOperation::Result::Failure, result
    assert_equal :error, result.failure
  end

  def test_mixin_success_with_dry_monads
    TypedOperation.configure { |c| c.result_adapter = :dry_monads }

    obj = MixinTest.new
    result = obj.create_success(42)

    assert_instance_of Dry::Monads::Result::Success, result
    assert_equal 42, result.value!
  end

  def test_mixin_failure_with_dry_monads
    TypedOperation.configure { |c| c.result_adapter = :dry_monads }

    obj = MixinTest.new
    result = obj.create_failure(:error)

    assert_instance_of Dry::Monads::Result::Failure, result
    assert_equal :error, result.failure
  end

  # --- Chain Integration ---

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

  def test_chains_use_built_in_by_default
    chain = AddOperation.then(DoubleOperation)
    result = chain.call(a: 2, b: 3)

    assert result.success?
    assert_equal 10, result.value![:result]
    assert_instance_of TypedOperation::Result::Success, result
  end

  def test_chains_use_dry_monads_when_configured
    TypedOperation.configure { |c| c.result_adapter = :dry_monads }

    chain = AddOperation.then(DoubleOperation)
    result = chain.call(a: 2, b: 3)

    assert result.success?
    assert_equal 10, result.value![:result]
    assert_instance_of Dry::Monads::Result::Success, result
  end

  # --- Interoperability ---

  class DryMonadsHelper
    include Dry::Monads[:result]

    def success(value)
      Success(value)
    end

    def failure(error)
      Failure(error)
    end
  end

  def test_built_in_success_duck_types_like_dry_monads
    helper = DryMonadsHelper.new
    built_in = TypedOperation::Result::Success.new(42)
    dry_monad = helper.success(42)

    assert_equal built_in.success?, dry_monad.success?
    assert_equal built_in.failure?, dry_monad.failure?
    assert_equal built_in.value!, dry_monad.value!
    assert_nil built_in.failure
    assert_nil dry_monad.failure
  end

  def test_built_in_failure_duck_types_like_dry_monads
    helper = DryMonadsHelper.new
    built_in = TypedOperation::Result::Failure.new(:error)
    dry_monad = helper.failure(:error)

    assert_equal built_in.success?, dry_monad.success?
    assert_equal built_in.failure?, dry_monad.failure?
    assert_equal built_in.failure, dry_monad.failure
  end
end
