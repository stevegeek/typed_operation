# frozen_string_literal: true

require "test_helper"
require "generators/typed_operation/install/install_generator"

class InstallGeneratorGeneratorTest < Rails::Generators::TestCase
  tests TypedOperation::Install::InstallGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  test "generator runs without errors" do
    assert_nothing_raised do
      run_generator
    end
  end

  test "generator creates application_operation file" do
    run_generator
    assert_file "app/operations/application_operation.rb"
  end

  test "generated file contains correct content" do
    run_generator

    assert_file "app/operations/application_operation.rb" do |content|
      assert_match(/class ApplicationOperation/, content)
      # Add more assertions for specific content as required...
    end
  end
end
