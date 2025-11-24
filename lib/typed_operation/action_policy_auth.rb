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

    # Class-level methods for configuring authorization on operations.
    module ClassMethods
      # Configure the operation to use ActionPolicy for authorization
      def authorized_via(*via, with: nil, to: nil, record: nil, &auth_block)
        raise ArgumentError, "You must not provide a policy class or method when using a block" if auth_block && (with || to)

        parameters = positional_parameters + keyword_parameters
        raise ArgumentError, "authorize_via must be called with a valid param name" unless via.all? { |param| parameters.include?(param) }
        @_authorized_via_param = via

        action_type_method = :"#{action_type}?" if action_type
        policy_method = to || action_type_method || raise(::TypedOperation::InvalidOperationError, "You must provide an action type or policy method name")
        @_policy_method = policy_method
        @_policy_class = if with
          with
        elsif auth_block
          policy_class = Class.new(OperationPolicy) do
            authorize(*via)

            define_method(policy_method, &auth_block)
          end
          const_set(:Policy, policy_class)
          policy_class
        else
          raise ::TypedOperation::InvalidOperationError, "You must provide either a policy class or a block"
        end

        if record
          unless parameters.include?(record) || method_defined?(record) || private_instance_methods.include?(record)
            raise ArgumentError, "to_authorize must be called with a valid param or method name"
          end
          @_to_authorize_param = record
        end

        # Configure action policy to use the param named in via as the context when instantiating the policy
        # ::ActionPolicy::Behaviour does not provide a authorize(*ids) method, so we have call once per param
        via.each do |param|
          authorize param
        end
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
        !(@_authorized_via_param.nil? || @_authorized_via_param.empty?)
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
      operation_class = self.class
      checks_auth = operation_class.checks_authorization?
      if operation_class.verify_authorized? && !checks_auth
        raise ::TypedOperation::MissingAuthentication, "Operation #{operation_class.name} must authorize. Remember to use `.authorize_via`"
      end
      operation_check_authorized! if checks_auth
      super
    end

    def operation_check_authorized!
      operation_class = self.class
      policy = operation_class.operation_policy_class
      raise "No Action Policy policy class provided, or no #{operation_class.name}::Policy found for this action" unless policy
      raise "No policy method provided or action_type not set for #{operation_class.name}" unless operation_class.operation_policy_method
      # Record to authorize, if nil then action policy tries to work it out implicitly
      record_to_authorize = send(operation_class.operation_record_to_authorize) if operation_class.operation_record_to_authorize

      authorize! record_to_authorize, to: operation_class.operation_policy_method, with: policy
    rescue ::ActionPolicy::Unauthorized => error
      on_authorization_failure(error)
      raise error
    end

    # A hook for subclasses to override to do something on an authorization failure
    def on_authorization_failure(_authorization_error)
      # noop
    end
  end
end
