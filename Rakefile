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

desc "Run code coverage"
task :coverage do
  ENV["COVERAGE"] = "1"
  Rake::Task["test"].invoke
  Rake::Task["rails_test"].invoke
end

# Add RubyCritic task with badge generation
begin
  require "rubycritic_small_badge"
  require "rubycritic/rake_task"

  RubyCriticSmallBadge.configure do |config|
    config.minimum_score = 90
  end

  RubyCritic::RakeTask.new do |task|
    # Exclude generator template files from analysis as they aren't valid Ruby
    task.paths = FileList["lib/**/*.rb"].exclude("lib/generators/**/templates/**/*.rb")

    task.options = %(--custom-format RubyCriticSmallBadge::Report
      --minimum-score #{RubyCriticSmallBadge.config.minimum_score}
      --coverage-path coverage/.resultset.json
      --no-browser)
  end

  desc "Run tests with coverage and then RubyCritic"
  task rubycritic_with_coverage: [:coverage, :rubycritic]
rescue LoadError
  desc "Run RubyCritic (not available)"
  task :rubycritic do
    puts "RubyCritic is not available"
  end
end

task default: [:test, :rails_test]
