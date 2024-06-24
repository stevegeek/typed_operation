# frozen_string_literal: true

require "rails/generators/base"

module TypedOperation
  module Install
    class InstallGenerator < Rails::Generators::Base
      class_option :dry_monads, type: :boolean, default: false
      class_option :action_policy, type: :boolean, default: false

      source_root File.expand_path("templates", __dir__)

      def copy_application_operation_file
        template "application_operation.rb", "app/operations/application_operation.rb"
      end

      private

      def include_dry_monads?
        options[:dry_monads]
      end

      def include_action_policy?
        options[:action_policy]
      end
    end
  end
end
