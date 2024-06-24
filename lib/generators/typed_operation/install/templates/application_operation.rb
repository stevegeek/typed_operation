# frozen_string_literal: true

class ApplicationOperation < ::TypedOperation::Base
<% if include_action_policy? -%>
  include TypedOperation::ActionPolicyAuth

<% end -%>
<% if include_dry_monads? -%>
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)

  # Helper to execute then unwrap a successful result or raise an exception
  def call!
    call.value!
  end

<% end -%>
  # Other common parameters & methods for Operations of this application...
  # Some examples:
  #
  #   def self.operation_key
  #     name.underscore.to_sym
  #   end
  #
  #   def operation_key
  #     self.class.operation_key
  #   end
  #
  #   # Translation and localization
  #
  #   def translate(key, **)
  #     key = "operations.#{operation_key}.#{key}" if key.start_with?(".")
  #     I18n.t(key, **)
  #   end
  #   alias_method :t, :translate
end
