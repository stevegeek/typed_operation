# frozen_string_literal: true

require "test_helper"

class MonadicChainingTest < Minitest::Test
  include Dry::Monads[:result]

  class ValidateEmailOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      email = context[:email]
      return Failure([:invalid_email, "Email must contain @"]) unless email.include?("@")
      return Failure([:invalid_email, "Email too short"]) if email.length < 5

      Success({ email: email })
    end
  end

  class NormalizeEmailOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      Success({ email: context[:email].downcase.strip })
    end
  end

  class FindOrCreateUserOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      user = { id: rand(1000), email: context[:email], created_at: Time.now }
      Success({ user: user })
    end
  end

  class SendWelcomeEmailOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      Success(context[:user].merge(welcome_email_sent: true))
    end
  end

  class UnreliableApiOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :data, Hash
    param :should_fail, _Boolean, default: false

    def perform
      return Failure([:api_error, "Service unavailable"]) if should_fail

      Success(data.merge(api_response: "success"))
    end
  end

  class FallbackOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :data, Hash
    param :should_fail, _Boolean, default: false

    def perform
      Success(data.merge(fallback: true, api_response: "fallback"))
    end
  end

  def test_basic_chaining_with_then_method
    chain = ValidateEmailOperation
              .then(NormalizeEmailOperation)
              .then(FindOrCreateUserOperation)

    result = chain.call({ email: "Test@Example.com" })

    assert result.success?, "Chain should succeed"
    user = result.value![:user]
    assert_equal "test@example.com", user[:email]
    assert user[:id]
  end

  def test_chaining_stops_on_first_failure
    chain = ValidateEmailOperation
              .then(NormalizeEmailOperation)
              .then(FindOrCreateUserOperation)

    result = chain.call({ email: "bad" })

    assert result.failure?, "Chain should fail at validation"
    code, message = result.failure
    assert_equal :invalid_email, code
    assert_equal "Email must contain @", message
  end

  def test_chaining_multiple_operations
    registration_pipeline = ValidateEmailOperation
                              .then(NormalizeEmailOperation)
                              .then(FindOrCreateUserOperation)
                              .then(SendWelcomeEmailOperation)

    result = registration_pipeline.call({ email: "New@User.com" })

    assert result.success?, "Full pipeline should succeed"
    user = result.value!
    assert_equal "new@user.com", user[:email]
    assert user[:welcome_email_sent]
  end

  def test_chaining_with_partial_application
    normalize_and_create = NormalizeEmailOperation
                             .then(FindOrCreateUserOperation)

    result1 = normalize_and_create.call({ email: "First@Example.com" })
    result2 = normalize_and_create.call({ email: "Second@Example.com" })

    assert result1.success?
    assert result2.success?
    assert_equal "first@example.com", result1.value![:user][:email]
    assert_equal "second@example.com", result2.value![:user][:email]
  end

  def test_and_then_with_block_for_monadic_bind
    chain = ValidateEmailOperation.and_then do |result|
      if result[:email].include?("test")
        Success(result.merge(test_account: true))
      else
        Success(result)
      end
    end

    result = chain.call({ email: "test@example.com" })

    assert result.success?
    assert result.value![:test_account]
  end

  def test_and_then_can_call_another_operation
    chain = ValidateEmailOperation.and_then do |result|
      NormalizeEmailOperation.call(result)
    end

    result = chain.call({ email: "Test@Example.com" })

    assert result.success?
    assert_equal "test@example.com", result.value![:email]
  end

  def test_and_then_short_circuits_on_failure
    chain = ValidateEmailOperation.and_then do |_result|
      raise "Should not be called"
    end

    result = chain.call({ email: "x" })

    assert result.failure?
    code, _message = result.failure
    assert_equal :invalid_email, code
  end

  def test_or_else_provides_fallback_on_failure
    chain = UnreliableApiOperation.or_else(FallbackOperation)

    result = chain.call(data: { value: 123 }, should_fail: true)

    assert result.success?, "Should succeed via fallback"
    assert_equal true, result.value![:fallback]
    assert_equal "fallback", result.value![:api_response]
  end

  def test_or_else_not_called_on_success
    chain = UnreliableApiOperation.or_else(FallbackOperation)

    result = chain.call(data: { value: 123 }, should_fail: false)

    assert result.success?, "Should succeed via main operation"
    refute result.value![:fallback]
    assert_equal "success", result.value![:api_response]
  end

  def test_or_else_with_block
    chain = UnreliableApiOperation.or_else do |_failure|
      Success(fallback: true, recovered: true)
    end

    result = chain.call(data: {}, should_fail: true)

    assert result.success?
    assert result.value![:fallback]
    assert result.value![:recovered]
  end

  def test_railway_pattern_with_recovery
    unreliable_step = UnreliableApiOperation.or_else(FallbackOperation)

    result = unreliable_step.call(data: { email: "test@example.com" }, should_fail: true)

    assert result.success?, "Should succeed via fallback"
    assert result.value![:fallback]
    assert_equal "test@example.com", result.value![:email]
  end

  def test_transform_maps_over_success_value
    chain = FindOrCreateUserOperation.transform do |result|
      user = result[:user]
      result.merge(transformed: true, name: user[:email].split("@").first)
    end

    result = chain.call({ email: "john@example.com" })

    assert result.success?
    assert result.value![:transformed]
    assert_equal "john", result.value![:name]
  end

  def test_transform_not_called_on_failure
    chain = ValidateEmailOperation.transform do |_result|
      raise "Should not be called on failure"
    end

    result = chain.call({ email: "x" })

    assert result.failure?
  end

  def test_transform_can_be_chained
    chain = FindOrCreateUserOperation
              .transform { |result| result.merge(step: 1) }
              .transform { |result| result.merge(step: 2) }
              .transform { |result| result.merge(final: true) }

    result = chain.call({ email: "test@example.com" })

    assert result.success?
    assert_equal 2, result.value![:step]
    assert result.value![:final]
  end

  def test_chaining_with_prepared_operations
    validate = ValidateEmailOperation.with
    normalize = NormalizeEmailOperation.with
    create_user = FindOrCreateUserOperation.with

    chain = validate.then(normalize).then(create_user)

    result = chain.call({ email: "test@example.com" })

    assert result.success?
    assert_equal "test@example.com", result.value![:user][:email]
  end

  def test_chaining_partially_applied_operations
    send_welcome = SendWelcomeEmailOperation.with

    chain = ValidateEmailOperation
              .then(NormalizeEmailOperation)
              .then(FindOrCreateUserOperation)
              .then(send_welcome)

    result = chain.call({ email: "test@example.com" })

    assert result.success?
    assert result.value![:welcome_email_sent]
  end

  def test_composed_operation_responds_to_call
    chain = ValidateEmailOperation.then(NormalizeEmailOperation)

    assert_respond_to chain, :call
  end

  def test_composed_operation_can_be_used_in_iteration
    chain = ValidateEmailOperation
              .then(NormalizeEmailOperation)
              .then(FindOrCreateUserOperation)

    emails = ["test1@example.com", "test2@example.com"]
    results = emails.map { |email| chain.call({ email: email }) }

    assert_equal 2, results.size
    assert results.all?(&:success?)
  end

  def test_composed_operation_is_immutable
    chain1 = ValidateEmailOperation.then(NormalizeEmailOperation)
    chain2 = chain1.then(FindOrCreateUserOperation)

    result1 = chain1.call({ email: "test@example.com" })
    result2 = chain2.call({ email: "test@example.com" })

    assert result1.success?
    assert result2.success?

    assert result1.value!.key?(:email)
    refute result1.value!.key?(:user)

    assert result2.value!.key?(:user)
    assert result2.value![:user].key?(:id)
  end

  def test_failure_preserves_error_context
    chain = ValidateEmailOperation
              .then(NormalizeEmailOperation)
              .then(FindOrCreateUserOperation)

    result = chain.call({ email: "bad" })

    assert result.failure?
    code, message = result.failure
    assert_equal :invalid_email, code
    assert_match(/must contain @/i, message)
  end

  class ExtractEmailOperation < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :context, Hash

    def perform
      Success({ email: context[:user][:email] })
    end
  end

  def test_chaining_operations_with_compatible_signatures
    chain = FindOrCreateUserOperation
              .then(ExtractEmailOperation)
              .then(NormalizeEmailOperation)

    result = chain.call({ email: "Test@Example.com" })

    assert result.success?
    assert_equal "test@example.com", result.value![:email]
  end

  def test_complete_user_registration_pipeline
    registration = ValidateEmailOperation
                     .then(NormalizeEmailOperation)
                     .then(FindOrCreateUserOperation)
                     .then(SendWelcomeEmailOperation)

    success_result = registration.call({ email: "NewUser@Example.com" })
    assert success_result.success?
    user = success_result.value!
    assert_equal "newuser@example.com", user[:email]
    assert user[:id]
    assert user[:welcome_email_sent]

    failure_result = registration.call({ email: "bad" })
    assert failure_result.failure?
    code, message = failure_result.failure
    assert_equal :invalid_email, code
    assert message
  end

  def test_mixing_transform_and_then
    chain = ValidateEmailOperation
              .then(NormalizeEmailOperation)
              .then(FindOrCreateUserOperation)
              .transform { |result| result.merge(processed: true) }

    result = chain.call({ email: "test@example.com" })

    assert result.success?
    assert result.value![:processed]
    assert result.value![:user]
  end

  class LegacyKwargsOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :email, String
    param :normalized, _Boolean, default: false

    def perform
      Success({ email: email, normalized: normalized, legacy: true })
    end
  end

  def test_and_then_to_bridge_to_kwargs_operation
    chain = ValidateEmailOperation.and_then do |result|
      LegacyKwargsOperation.call(email: result[:email], normalized: true)
    end

    result = chain.call({ email: "test@example.com" })

    assert result.success?
    assert result.value![:legacy]
    assert result.value![:normalized]
  end

  class CreateUserFromKwargs < TypedOperation::Base
    include Dry::Monads[:result]

    param :email, String
    param :name, String

    def perform
      Success({ id: rand(1000), email: email, name: name })
    end
  end

  class ValidateUserInput < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :input, Hash

    def perform
      return Failure(:invalid) unless input[:email]&.include?("@")

      Success({ email: input[:email].downcase, name: input[:name] || "Anonymous" })
    end
  end

  def test_smart_then_auto_splats_to_kwargs_operation
    # ValidateUserInput returns {email:, name:}
    # CreateUserFromKwargs has param :email, param :name (kwargs)
    # Smart .then should auto-splat
    chain = ValidateUserInput.then(CreateUserFromKwargs)

    result = chain.call({ email: "TEST@example.com", name: "Alice" })

    assert result.success?
    assert result.value![:id]
    assert_equal "test@example.com", result.value![:email]
    assert_equal "Alice", result.value![:name]
  end

  def test_smart_then_passes_value_to_positional_param_operation
    # NormalizeEmailOperation has positional_param :context, Hash
    # Smart .then should pass as single value
    chain = ValidateEmailOperation.then(NormalizeEmailOperation)

    result = chain.call({ email: "TEST@example.com" })

    assert result.success?
    assert_equal "test@example.com", result.value![:email]
  end

  def test_smart_then_raises_for_mixed_positional_and_kwargs
    mixed_op = Class.new(TypedOperation::Base) do
      include Dry::Monads[:result]
      positional_param :data, Hash
      param :extra, String

      def perform
        Success(data.merge(extra: extra))
      end
    end

    assert_raises ArgumentError do
      ValidateEmailOperation.then(mixed_op)
    end
  end

  def test_then_splat_always_splats_as_kwargs
    chain = ValidateUserInput.then_splat(CreateUserFromKwargs)

    result = chain.call({ email: "Test@Example.com", name: "Bob" })

    assert result.success?
    assert_equal "test@example.com", result.value![:email]
    assert_equal "Bob", result.value![:name]
  end

  def test_then_value_always_passes_as_single_arg
    chain = ValidateEmailOperation.then_value(NormalizeEmailOperation)

    result = chain.call({ email: "Test@Example.com" })

    assert result.success?
    assert_equal "test@example.com", result.value![:email]
  end

  def test_then_splat_raises_for_non_hashable_value
    string_op = Class.new(TypedOperation::Base) do
      include Dry::Monads[:result]

      def perform
        Success("not a hash")
      end
    end

    chain = string_op.then_splat(CreateUserFromKwargs)

    assert_raises ArgumentError do
      chain.call
    end
  end

  def test_then_with_data_object
    user_data = Data.define(:email, :name)

    data_op = Class.new(TypedOperation::Base) do
      include Dry::Monads[:result]
      define_method(:user_data) { user_data }

      def perform
        Success(user_data.new(email: "test@example.com", name: "DataUser"))
      end
    end

    chain = data_op.then_splat(CreateUserFromKwargs)
    result = chain.call

    assert result.success?
    assert_equal "test@example.com", result.value![:email]
    assert_equal "DataUser", result.value![:name]
  end

  def test_then_with_proc_defaults_to_pass
    chain = ValidateEmailOperation.then(->(ctx) {
      Dry::Monads::Success(ctx.merge(from_proc: true))
    })

    result = chain.call({ email: "test@example.com" })

    assert result.success?
    assert result.value![:from_proc]
  end

  def test_then_with_partially_applied_operation
    # PartiallyApplied should extract operation_class for introspection
    partial = CreateUserFromKwargs.with(name: "DefaultName")

    # ValidateUserInput returns {email:, name:}, partial expects {email:} (name already applied)
    # But the introspection should see CreateUserFromKwargs has kwargs, so it splats
    chain = ValidateUserInput.then(partial)

    result = chain.call({ email: "TEST@example.com" })

    assert result.success?
    assert_equal "test@example.com", result.value![:email]
    # Name comes from the return value, not the partial application
    # Because we're splatting the whole hash
    assert_equal "Anonymous", result.value![:name]
  end
end
