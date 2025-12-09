# frozen_string_literal: true

require "test_helper"

# Tests to verify that Result monad composition satisfies the monad laws.
# These laws ensure that monadic composition behaves predictably and associatively.
#
# The three monad laws:
# 1. Left identity:  return a >>= f  ≡  f a
# 2. Right identity: m >>= return    ≡  m
# 3. Associativity:  (m >>= f) >>= g ≡  m >>= (\x -> f x >>= g)
#
# Note: This tests the Result monad (Dry::Monads), not operation composition.
# For operation composition tests, see monadic_chaining_test.rb and integration_example_test.rb.
class MonadLawsTest < Minitest::Test
  include Dry::Monads[:result]

  def setup
    TypedOperation.configure { |c| c.result_adapter = :dry_monads }
  end

  def teardown
    TypedOperation.reset_configuration!
  end

  # Simple operations that use kwargs and return Success(Hash)
  class DoubleOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :x, Integer

    def perform
      Success({x: x * 2})
    end
  end

  class IncrementOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :x, Integer

    def perform
      Success({x: x + 1})
    end
  end

  class SquareOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :x, Integer

    def perform
      Success({x: x * x})
    end
  end

  class FailingOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :x, Integer

    def perform
      Failure([:error, "Always fails"])
    end
  end

  # ============================================================================
  # LEFT IDENTITY LAW
  # ============================================================================
  # Law: return a >>= f  ≡  f a
  # In Ruby: Success(value).bind { |v| f(v) } ≡ f(value)

  def test_left_identity_with_bind
    value = {x: 5}

    # Left side: Wrap in Success then bind
    left_result = Success(value).bind { |v| DoubleOperation.call(**v) }

    # Right side: Call directly
    right_result = DoubleOperation.call(**value)

    assert_equal left_result, right_result
    assert_equal 10, left_result.value![:x]
  end

  def test_left_identity_direct_call
    result = DoubleOperation.call(x: 5)

    assert result.success?
    assert_equal 10, result.value![:x]
  end

  # ============================================================================
  # RIGHT IDENTITY LAW
  # ============================================================================
  # Law: m >>= return  ≡  m
  # In Ruby: operation.bind { |v| Success(v) } ≡ operation

  def test_right_identity_wrapping_in_success
    # Left side: Operation result bound with Success wrapper
    left_result = DoubleOperation.call(x: 5).bind { |v| Success(v) }

    # Right side: Just the operation result
    right_result = DoubleOperation.call(x: 5)

    assert_equal left_result, right_result
    assert_equal 10, left_result.value![:x]
  end

  def test_right_identity_with_transform
    # Using transform with identity function should not change result
    chain = DoubleOperation.transform { |v| v }
    result = chain.call(x: 5)

    direct_result = DoubleOperation.call(x: 5)

    assert_equal result, direct_result
    assert_equal 10, result.value![:x]
  end

  # ============================================================================
  # ASSOCIATIVITY LAW
  # ============================================================================
  # Law: (m >>= f) >>= g  ≡  m >>= (\x -> f x >>= g)
  # In Ruby: Different groupings of binds should produce same result

  def test_associativity_left_grouping
    # (m >>= f) >>= g
    result = DoubleOperation.call(x: 5)
      .bind { |v| IncrementOperation.call(**v) }
      .bind { |v| SquareOperation.call(**v) }

    # Expected: (5 * 2) = 10, (10 + 1) = 11, (11 * 11) = 121
    assert result.success?
    assert_equal 121, result.value![:x]
  end

  def test_associativity_right_grouping
    # m >>= (\x -> f x >>= g)
    result = DoubleOperation.call(x: 5).bind do |v|
      IncrementOperation.call(**v).bind { |v2| SquareOperation.call(**v2) }
    end

    assert result.success?
    assert_equal 121, result.value![:x]
  end

  def test_associativity_groupings_are_equivalent
    # Left grouping
    result_left = DoubleOperation.call(x: 5)
      .bind { |v| IncrementOperation.call(**v) }
      .bind { |v| SquareOperation.call(**v) }

    # Right grouping (nested binds)
    result_right = DoubleOperation.call(x: 5).bind do |v|
      IncrementOperation.call(**v).bind { |v2| SquareOperation.call(**v2) }
    end

    assert_equal result_left, result_right
    assert_equal 121, result_left.value![:x]
  end

  def test_associativity_with_longer_chain
    # Longer chain demonstrates associativity holds for multiple operations
    result1 = DoubleOperation.call(x: 2)
      .bind { |v| IncrementOperation.call(**v) }
      .bind { |v| DoubleOperation.call(**v) }
      .bind { |v| SquareOperation.call(**v) }

    # Different grouping
    result2 = DoubleOperation.call(x: 2).bind do |v|
      IncrementOperation.call(**v).bind do |v2|
        DoubleOperation.call(**v2).bind { |v3| SquareOperation.call(**v3) }
      end
    end

    # (2*2)=4, (4+1)=5, (5*2)=10, (10*10)=100
    assert_equal result1, result2
    assert_equal 100, result1.value![:x]
  end

  # ============================================================================
  # FAILURE PROPAGATION (Monad laws with failures)
  # ============================================================================

  def test_left_identity_with_failure
    value = {x: 5}

    # If f returns Failure, binding should preserve it
    left_result = Success(value).bind { |v| FailingOperation.call(**v) }
    right_result = FailingOperation.call(**value)

    assert_equal left_result, right_result
    assert left_result.failure?
  end

  def test_failure_short_circuits_in_chain
    result = DoubleOperation.call(x: 5)
      .bind { |v| FailingOperation.call(**v) }
      .bind { |v| SquareOperation.call(**v) }  # Should never execute

    assert result.failure?
    code, message = result.failure
    assert_equal :error, code
    assert_equal "Always fails", message
  end

  def test_associativity_with_failure
    # Chain that fails, grouped different ways
    result_left = DoubleOperation.call(x: 5)
      .bind { |v| FailingOperation.call(**v) }
      .bind { |v| SquareOperation.call(**v) }

    result_right = DoubleOperation.call(x: 5).bind do |v|
      FailingOperation.call(**v).bind { |v2| SquareOperation.call(**v2) }
    end

    # Both should fail at same point with same error
    assert_equal result_left, result_right
    assert result_left.failure?
  end

  # ============================================================================
  # TRANSFORM (FUNCTOR) LAWS
  # ============================================================================
  # Functor laws:
  # 1. Identity: fmap id ≡ id
  # 2. Composition: fmap (f . g) ≡ fmap f . fmap g

  def test_transform_identity_law
    # Transform with identity should equal identity
    chain = DoubleOperation.transform { |v| v }
    result = chain.call(x: 5)

    direct_result = DoubleOperation.call(x: 5)

    assert_equal result, direct_result
  end

  def test_transform_composition_law
    f = ->(hash) { hash.merge(doubled: true) }
    g = ->(hash) { hash.merge(tagged: true) }

    # fmap (f . g) - compose then transform
    chain1 = DoubleOperation.transform { |v| g.call(f.call(v)) }

    # (fmap f) . (fmap g) - transform then transform
    chain2 = DoubleOperation.transform(&f).transform(&g)

    result1 = chain1.call(x: 5)
    result2 = chain2.call(x: 5)

    assert_equal result1, result2
    assert result1.value![:doubled]
    assert result1.value![:tagged]
  end
end
