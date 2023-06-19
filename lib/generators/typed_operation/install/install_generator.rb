# frozen_string_literal: true

require "rails/generators/base"

module TypedOperation
  module Install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def copy_application_operation_file
        copy_file "application_operation.rb", "app/operations/application_operation.rb"
      end
    end
  end
end
