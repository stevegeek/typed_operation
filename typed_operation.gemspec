require_relative "lib/typed_operation/version"

Gem::Specification.new do |spec|
  spec.name = "typed_operation"
  spec.version = TypedOperation::VERSION
  spec.authors = ["Stephen Ierodiaconou"]
  spec.email = ["stevegeek@gmail.com"]
  spec.homepage = "https://github.com/stevegeek/typed_operation"
  spec.summary = "TypedOperation is a command pattern with typed parameters, which is callable, and can be partially applied."
  spec.description = "Command pattern, which is callable, and can be partially applied, curried and has typed parameters. Authorization to execute via action_policy if desired."
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/stevegeek/typed_operation"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "MIT-LICENSE", "README.md"]
  end

  # spec.add_dependency "literal", "> 0.1.0", "< 1.0.0"
end
