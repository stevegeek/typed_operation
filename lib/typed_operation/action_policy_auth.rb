# frozen_string_literal: true

require "action_policy"

# An optional module to include in your operation to enable authorization via ActionPolicies
module TypedOperation
  class MissingAuthentication < StandardError; end

  module ActionPolicyAuth
    # Base class for any action policy classes used by operations
    class OperationPolicy
      include ActionPolicy::Policy::Core
      include ActionPolicy::Policy::Authorization
      include ActionPolicy::Policy::PreCheck
      include ActionPolicy::Policy::Reasons
      include ActionPolicy::Policy::Aliases
      include ActionPolicy::Policy::Scoping
      include ActionPolicy::Policy::Cache
      include ActionPolicy::Policy::CachedApply
    end

    def self.included(base)
      base.include ::ActionPolicy::Behaviour
      base.extend ClassMethods
    end

    module ClassMethods
      # Ensure that the initiator is provided and authorized to perform this operation. Setup for action_policy and
      # hooks to check permissions.
      # Define the policy class and method to use for authorization:
      # You can either do this via the block where you can define the auth rule inline:
      #
      #     authorized_via :initiator do
      #       initiator.is_a?(Admin)
      #     end
      #
      # Or by providing a policy class and method name:
      #
      #     class Policy < OperationPolicy
      #       authorize :initiator
      #
      #       def my_action_name?
      #         initiator.is_a?(Admin)
      #       end
      #     end
      #
      #     authorized_via :initiator, with: Policy, to: :my_action_name?
      #
      def authorized_via(via = :initiator, with: nil, to: nil, record: nil, &auth_block)
        # If a block is provided, you must not provide a policy class or method
        raise ArgumentError, "You must not provide a policy class or method when using a block" if auth_block && (with || to)

        parameters = positional_parameters + keyword_parameters
        raise ArgumentError, "authorize_via must be called with a valid param name" unless parameters.include?(via)
        @_authorized_via_param = via

        action_type_method = "#{action_type}?".to_sym if action_type
        # If an method name is provided, use it
        policy_method = to || action_type_method || raise(::TypedOperation::InvalidOperationError, "You must provide an action type or policy method name")
        @_policy_method = policy_method
        # If a policy class is provided, use it
        @_policy_class = if with
          with
        elsif auth_block
          policy_class = Class.new(OperationPolicy) do
            authorize via

            define_method(policy_method, &auth_block)
          end
          const_set(:Policy, policy_class)
          policy_class
        else
          raise ::TypedOperation::InvalidOperationError, "You must provide either a policy class or a block"
        end

        if record
          raise ArgumentError, "to_authorize must be called with a valid param name" unless parameters.include?(record)
          @_to_authorize_param = record
        end

        # Configure action policy to use the param named in via as the context when instantiating the policy
        authorize via
      end

      def action_type(type = nil)
        @_action_type = type.to_sym if type
        @_action_type
      end

      def operation_policy_method
        @_policy_method
      end

      def operation_policy_class
        @_policy_class
      end

      def operation_record_to_authorize
        @_to_authorize_param
      end

      def checks_authorization?
        @_authorized_via_param.is_a?(Symbol)
      end

      # You can use this on an operation base class to ensure and subclasses always enable authorization
      def verify_authorized!
        return if verify_authorized?
        @_verify_authorized = true
      end

      def verify_authorized?
        @_verify_authorized
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@_authorized_via_param, @_authorized_via_param)
        subclass.instance_variable_set(:@_verify_authorized, @_verify_authorized)
        subclass.instance_variable_set(:@_policy_class, @_policy_class)
        subclass.instance_variable_set(:@_policy_method, @_policy_method)
        subclass.instance_variable_set(:@_action_type, @_action_type)
      end
    end

    private

    # Redefine it as private
    def execute_operation
      if self.class.verify_authorized? && !self.class.checks_authorization?
        raise ::TypedOperation::MissingAuthentication, "Operation #{self.class.name} must authorize. Remember to use `.authorize_via`"
      end
      operation_check_authorized! if self.class.checks_authorization?
      super
    end

    def operation_check_authorized!
      policy = self.class.operation_policy_class
      raise "No Action Policy policy class provided, or no #{self.class.name}::Policy found for this action" unless policy
      policy_method = self.class.operation_policy_method
      raise "No policy method provided or action_type not set for #{self.class.name}" unless policy_method
      # Record to authorize, if nil then action policy tries to work it out implicitly
      record_to_authorize = send(self.class.operation_record_to_authorize) if self.class.operation_record_to_authorize

      authorize! record_to_authorize, to: policy_method, with: policy
    rescue ::ActionPolicy::Unauthorized => e
      on_authorization_failure(e)
      raise e
    end

    # A hook for subclasses to override to do something on an authorization failure
    def on_authorization_failure(authorization_error)
      # noop
    end
  end
end
