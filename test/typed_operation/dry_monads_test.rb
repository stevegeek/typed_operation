# frozen_string_literal: true

require "test_helper"

class DryMonadsTest < Minitest::Test
  class ValidateAgeOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :age, Integer

    def perform
      if age >= 18
        Success(age)
      else
        Failure(:too_young)
      end
    end
  end

  def test_success_result
    result = ValidateAgeOperation.call(age: 25)

    assert result.success?
    assert_equal 25, result.value!
  end

  def test_failure_result
    result = ValidateAgeOperation.call(age: 16)

    assert result.failure?
    assert_equal :too_young, result.failure
  end

  class CreateAccountOperation < TypedOperation::Base
    include Dry::Monads[:result]
    include Dry::Monads::Do.for(:perform)

    param :email, String
    param :age, Integer

    def perform
      validated_age = yield ValidateAgeOperation.call(age: age)
      Success({ email: email, age: validated_age })
    end
  end

  def test_do_notation_success
    result = CreateAccountOperation.call(email: "test@example.com", age: 25)

    assert result.success?
    assert_equal "test@example.com", result.value![:email]
    assert_equal 25, result.value![:age]
  end

  def test_do_notation_failure_short_circuits
    result = CreateAccountOperation.call(email: "test@example.com", age: 16)

    assert result.failure?
    assert_equal :too_young, result.failure
  end

  class AuthenticateOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :email, String
    param :password, String

    def perform
      return Failure([:not_found, "User not found"]) if email != "valid@example.com"
      return Failure([:invalid_password, "Wrong password"]) if password != "secret"

      Success({ email: email })
    end
  end

  def test_structured_error_user_not_found
    result = AuthenticateOperation.call(email: "wrong@example.com", password: "secret")

    assert result.failure?
    code, message = result.failure
    assert_equal :not_found, code
    assert_equal "User not found", message
  end

  def test_structured_error_invalid_password
    result = AuthenticateOperation.call(email: "valid@example.com", password: "wrong")

    assert result.failure?
    code, message = result.failure
    assert_equal :invalid_password, code
    assert_equal "Wrong password", message
  end

  def test_authentication_success
    result = AuthenticateOperation.call(email: "valid@example.com", password: "secret")

    assert result.success?
    assert_equal "valid@example.com", result.value![:email]
  end

  def test_pattern_matching_with_result
    result = ValidateAgeOperation.call(age: 25)

    message = case result
              in Dry::Monads::Success(age)
                "Age #{age} is valid"
              in Dry::Monads::Failure(:too_young)
                "Too young"
              end

    assert_equal "Age 25 is valid", message
  end

  def test_pattern_matching_with_failure
    result = ValidateAgeOperation.call(age: 16)

    message = case result
              in Dry::Monads::Success(age)
                "Age #{age} is valid"
              in Dry::Monads::Failure(:too_young)
                "Too young"
              end

    assert_equal "Too young", message
  end

  def test_value_or_with_success
    result = ValidateAgeOperation.call(age: 25)
    value = result.value_or(18)

    assert_equal 25, value
  end

  def test_value_or_with_failure
    result = ValidateAgeOperation.call(age: 16)
    value = result.value_or(18)

    assert_equal 18, value
  end

  def test_either_with_success
    result = ValidateAgeOperation.call(age: 25)

    output = result.either(
      ->(age) { "Valid: #{age}" },
      ->(_error) { "Invalid" }
    )

    assert_equal "Valid: 25", output
  end

  def test_either_with_failure
    result = ValidateAgeOperation.call(age: 16)

    output = result.either(
      ->(age) { "Valid: #{age}" },
      ->(error) { "Invalid: #{error}" }
    )

    assert_equal "Invalid: too_young", output
  end
end
