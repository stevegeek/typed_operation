# frozen_string_literal: true

require "test_helper"
require "generators/typed_operation_generator"

class OperationGeneratorTest < Rails::Generators::TestCase
  tests TypedOperationGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  test "generator runs without errors" do
    assert_nothing_raised do
      run_generator ["TestOperation", "--path=app/operations"]
    end
  end

  test "generator creates operation file" do
    run_generator ["TestOperation", "--path=app/operations"]
    assert_file "app/operations/test_operation.rb"
    assert_file "test/operations/test_operation_test.rb"
  end

  test "generated file contains correct content" do
    run_generator ["TestOperation", "--path=app/operations"]

    assert_file "app/operations/test_operation.rb" do |content|
      assert_not_includes("module App::Operations", content)
      assert_match(/class TestOperation < ::ApplicationOperation/, content)
      assert_match(/param :required_param, String/, content)
    end

    assert_file "test/operations/test_operation_test.rb" do |content|
      assert_not_includes("module App::Operations", content)
      assert_match(/class TestOperationTest < ActiveSupport::TestCase/, content)
    end
  end

  test "generated file contains correct content with alternate path" do
    run_generator ["TestPathOperation", "--path=app/things/stuff"]

    assert_file "app/things/stuff/test_path_operation.rb" do |content|
      assert_match(/module Stuff/, content)
      assert_match(/class TestPathOperation < ::ApplicationOperation/, content)
      assert_match(/param :an_optional_param, Integer, allow_nil: true do/, content)
    end

    assert_file "test/things/stuff/test_path_operation_test.rb" do |content|
      assert_match(/module Stuff/, content)
      assert_match(/class TestPathOperationTest < ActiveSupport::TestCase/, content)
    end
  end
end
