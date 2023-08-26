# frozen_string_literal: true

require "test_helper"

require "typed_operation/action_policy_auth"

module TypedOperation
  class ActionPolicyAuthTest < Minitest::Test
    User = Struct.new(:name)

    class TestAuthBaseOperation < ::TypedOperation::Base
      include ::TypedOperation::ActionPolicyAuth

      param :your_name, String
      param :initiator, optional(User)
      param :friend, optional(User)

      def perform
        "Hi #{your_name}! I am #{initiator&.name || "?"}"
      end
    end

    class TestOperationWithAuth < TestAuthBaseOperation
      action_type :say_hi

      authorized_via :initiator do
        initiator.name == "Admin"
      end
    end

    class TestOperationNoAuthConfigured < TestAuthBaseOperation
      action_type :say_hi
    end

    class TestOperationAuthWithInheritance < TestOperationNoAuthConfigured
      class MyPolicy < OperationPolicy
        def say_hi?
          true
        end
      end

      authorized_via :initiator, with: MyPolicy
    end

    class TestOperationWithNoPolicyAuthMethod < TestOperationNoAuthConfigured
      class Policy < OperationPolicy
        def foo?
          true
        end
      end

      authorized_via :initiator, with: Policy
    end

    class TestOperationWithRequiredAuth < TestAuthBaseOperation
      action_type :say_hi

      verify_authorized!
    end

    class TestOperationWithRequiredAuthAndNoAuthDefined < TestOperationWithRequiredAuth
    end

    class TestOperationWithRequiredAuthAndAuthDefined < TestOperationWithRequiredAuth
      authorized_via :initiator do
        initiator.name == "Admin"
      end
    end

    class TestOperationWithAuthRecord < TestOperationWithRequiredAuth
      authorized_via :initiator, record: :friend do
        initiator.name == "Admin" && record.name == "Alice"
      end
    end

    class TestOperationWithAuthViaMultiple < TestOperationWithRequiredAuth
      authorized_via :initiator, :friend do
        initiator.name == "Admin" && friend.name == "Alice"
      end
    end

    def setup
      @admin = User.new("Admin")
      @alice = User.new("Alice")
      @not_admin = User.new("Not Admin")
    end

    def test_fails_to_execute_authed_operation_with_nil_context
      assert_raises(ActionPolicy::AuthorizationContextMissing) { TestOperationWithAuth.new(your_name: "Alice").call }
      assert_raises(ActionPolicy::AuthorizationContextMissing) { TestOperationWithAuth.new(your_name: "Alice", initiator: nil).call }
    end

    def test_fails_to_execute_authed_operation_with_unauthorized_context
      assert_raises(ActionPolicy::Unauthorized) { TestOperationWithAuth.new(your_name: "Alice", initiator: @not_admin).call }
    end

    def test_successful_operation_with_auth
      assert_equal "Hi Alice! I am Admin", TestOperationWithAuth.new(your_name: "Alice", initiator: @admin).call
    end

    # test "authorized_via raises when trying to set policy and define inline auth rule" do
    def test_authorized_via_raises_when_trying_to_set_policy_and_define_inline_auth_rule
      assert_raises(ArgumentError) do
        Class.new(TestAuthBaseOperation) do
          authorized_via :initiator, with: TestAuthBaseOperation::OperationPolicy do
            true
          end
        end
      end
    end

    def test_authorized_via_raises_when_trying_to_set_action_name_and_define_inline_auth_rule
      assert_raises(ArgumentError) do
        Class.new(TestAuthBaseOperation) do
          authorized_via :initiator, to: :my_name? do
            true
          end
        end
      end
    end

    def test_authorized_via_raises_when_the_via_param_option_specifies_an_invalid_param_name
      assert_raises(ArgumentError) do
        Class.new(TestAuthBaseOperation) do
          authorized_via(:foo) { true }
        end
      end
    end

    def test_authorized_via_raises_when_policy_is_not_set
      assert_raises(::TypedOperation::InvalidOperationError) do
        Class.new(TestAuthBaseOperation) do
          action_type :say_hi

          authorized_via :initiator
        end
      end
    end

    def test_authorized_via_raises_when_action_not_set
      assert_raises(::TypedOperation::InvalidOperationError) do
        Class.new(TestAuthBaseOperation) do
          authorized_via :initiator, with: TestAuthBaseOperation::OperationPolicy
        end
      end
    end

    def test_authorized_via_raises_when_policy_not_set_and_action_set_via_to
      assert_raises(::TypedOperation::InvalidOperationError) do
        Class.new(TestAuthBaseOperation) do
          authorized_via :initiator, to: :say_hi?
        end
      end
    end

    def test_authorized_via_raises_when_record_not_valid_param_or_method
      assert_raises(ArgumentError) do
        Class.new(TestAuthBaseOperation) do
          action_type :say_hi

          authorized_via(:initiator, record: :foo) { true }
        end
      end
    end

    def test_authorized_via_does_not_raise_when_record_is_method
      Class.new(TestAuthBaseOperation) do
        action_type :say_hi

        def foo
          "foo"
        end

        authorized_via(:initiator, record: :foo) { true }
      end
    end

    def test_successful_operation_without_authorization_if_its_not_needed_by_the_operation
      assert_equal TestOperationNoAuthConfigured.with(your_name: "Alice").call, "Hi Alice! I am ?"
    end

    def test_successful_operation_with_inheritance
      res = TestOperationAuthWithInheritance.with(your_name: "Alice").call(initiator: @admin)
      assert_equal "Hi Alice! I am Admin", res
    end

    def test_it_raises_if_policy_class_does_not_define_the_policy_method
      assert_raises(ActionPolicy::UnknownRule) do
        TestOperationWithNoPolicyAuthMethod.with(your_name: "Alice").call(initiator: @admin)
      end
    end

    def test_it_raises_if_no_auth_was_defined_when_required
      assert_raises(TypedOperation::MissingAuthentication) do
        TestOperationWithRequiredAuthAndNoAuthDefined.with(your_name: "Alice").call
      end
    end

    def test_it_does_not_raise_if_auth_was_defined_when_required
      assert_equal "Hi Alice! I am Admin", TestOperationWithRequiredAuthAndAuthDefined.with(your_name: "Alice", initiator: @admin).call
    end

    def test_authorizes_with_record
      assert_equal "Hi Alice! I am Admin", TestOperationWithAuthRecord.with(your_name: "Alice", initiator: @admin, friend: @alice).call
    end

    def test_fails_to_authorize_with_record
      assert_raises(ActionPolicy::Unauthorized) { TestOperationWithAuthRecord.with(your_name: "Alice", initiator: @admin, friend: @not_admin).call }
    end

    def test_authorizes_with_multiple_via
      assert_equal "Hi Alice! I am Admin", TestOperationWithAuthViaMultiple.with(your_name: "Alice", initiator: @admin, friend: @alice).call
    end

    def test_fails_to_authorize_with_multiple_via
      assert_raises(ActionPolicy::Unauthorized) { TestOperationWithAuthViaMultiple.with(your_name: "Alice", initiator: @admin, friend: @not_admin).call }
    end
  end
end
