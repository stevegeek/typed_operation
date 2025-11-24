# frozen_string_literal: true

require "test_helper"

# Tests for examples from pattern-matching.md
class PatternMatchingTest < Minitest::Test
  # Basic pattern matching example
  class UserOperation < TypedOperation::Base
    param :email, String
    param :age, Integer

    def perform
      self
    end
  end

  def test_pattern_matching_with_deconstruct_keys
    operation = UserOperation.new(email: "test@example.com", age: 25)

    result = case operation
             in { email:, age: 18.. }
               "Adult: #{email}"
             in { email: }
               "Minor: #{email}"
             end

    assert_equal "Adult: test@example.com", result
  end

  def test_pattern_matching_minor
    operation = UserOperation.new(email: "teen@example.com", age: 16)

    result = case operation
             in { email:, age: 18.. }
               "Adult: #{email}"
             in { email: }
               "Minor: #{email}"
             end

    assert_equal "Minor: teen@example.com", result
  end

  # Pattern matching with specific values
  class StatusOperation < TypedOperation::Base
    param :status, String
    param :message, String

    def perform
      self
    end
  end

  def test_pattern_matching_specific_values
    operation = StatusOperation.new(status: "success", message: "Done")

    result = case operation
             in { status: "success", message: }
               "Success: #{message}"
             in { status: "error", message: }
               "Error: #{message}"
             else
               "Unknown"
             end

    assert_equal "Success: Done", result
  end

  # Pattern matching in method
  class ProcessResult
    def self.handle(operation)
      case operation
      in { status: "success" }
        :ok
      in { status: "error" }
        :failed
      else
        :unknown
      end
    end
  end

  def test_pattern_matching_in_method
    success_op = StatusOperation.new(status: "success", message: "OK")
    error_op = StatusOperation.new(status: "error", message: "Failed")

    assert_equal :ok, ProcessResult.handle(success_op)
    assert_equal :failed, ProcessResult.handle(error_op)
  end

  # Pattern matching with regex (using hash destructuring)
  def test_pattern_matching_with_regex
    operation = UserOperation.new(email: "test@example.com", age: 30)

    result = case operation
             in { email: /admin/i, age: }
               "Admin with age #{age}"
             in { email:, age: 18.. }
               "Regular adult: #{email}"
             else
               "Other"
             end

    assert_equal "Regular adult: test@example.com", result
  end

  def test_pattern_matching_with_regex_match
    operation = UserOperation.new(email: "admin@example.com", age: 30)

    result = case operation
             in { email: /admin/i, age: }
               "Admin with age #{age}"
             in { email:, age: 18.. }
               "Regular adult: #{email}"
             else
               "Other"
             end

    assert_equal "Admin with age 30", result
  end
end
