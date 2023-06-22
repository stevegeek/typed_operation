require_relative "lib/typed_operation/version"

Gem::Specification.new do |spec|
  spec.name = "typed_operation"
  spec.version = TypedOperation::VERSION
  spec.authors = ["Stephen Ierodiaconou"]
  spec.email = ["stevegeek@gmail.com"]
  spec.homepage = "https://github.com/stevegeek/typed_operation"
  spec.summary = "TypedOperation is a command pattern implementation"
  spec.description = "TypedOperation is a command pattern implementation where inputs can be defined with runtime type checks. Operations can be partially applied."
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/stevegeek/typed_operation"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 6.0", "< 8.0"
  spec.add_dependency "vident-typed", "~> 0.1.0"
  spec.add_dependency "dry-initializer", "~> 3.0"
end
