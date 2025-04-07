require "bundler/setup"
require "bundler/gem_tasks"

desc "Run all tests"
task :test do
  sh "bin/test"
end

desc "Run Rails tests"
task :rails_test do
  sh "bin/rails_test"
end

task default: [:test, :rails_test]
