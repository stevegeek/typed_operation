source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in typed_operation.gemspec.
gemspec

gem "literal", "~> 1.0"

gem "standard"
gem "simplecov"

gem "rails"
gem "sqlite3"
gem "dry-monads"
gem "action_policy"

gem "appraisal", require: false

# gem "typed_operation"
# gem "type_fusion"

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2.0")
  gem "polyfill-data"
end
