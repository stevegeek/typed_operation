# frozen_string_literal: true

require "rails/generators/named_base"

class TypedOperationGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  class_option :path, type: :string, default: "app/operations"

  def generate_operation
    template_path = File.join(self.class.source_root, "operation.rb")
    dest_path = File.join(options[:path], "#{file_name}.rb")

    template(template_path, dest_path)
  end

  private

  def namespace_name
    namespace_path = options[:path].gsub(/^app\/[^\/]*\//, "")
    namespace_path.split("/").map(&:camelize).join("::")
  end
end
