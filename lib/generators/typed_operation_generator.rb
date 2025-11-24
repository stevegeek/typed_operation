# frozen_string_literal: true

require "rails/generators/named_base"

# Rails generator for creating new typed operation files and their tests.
class TypedOperationGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  class_option :path, type: :string, default: "app/operations"

  def generate_operation
    source_root = self.class.source_root
    operation_path = options[:path]

    template(
      File.join(source_root, "operation.rb"),
      File.join(operation_path, "#{file_name}.rb")
    )
    template(
      File.join(source_root, "operation_test.rb"),
      File.join("test/", operation_path.gsub(/\Aapp\//, ""), "#{file_name}_test.rb")
    )
  end

  private

  def namespace_name
    namespace_path = options[:path].gsub(/^app\/[^\/]*\//, "")
    namespace_path.split("/").map(&:camelize).join("::")
  end
end
