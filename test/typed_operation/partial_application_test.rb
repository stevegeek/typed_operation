# frozen_string_literal: true

require "test_helper"

class PartialApplicationTest < Minitest::Test
  class SendEmailOperation < TypedOperation::Base
    param :from, String
    param :to, String
    param :subject, String
    param :body, String

    def perform
      { from: from, to: to, subject: subject, body: body }
    end
  end

  def test_partial_application_with_from
    send_email = SendEmailOperation.with(from: "noreply@example.com")

    result = send_email.call(
      to: "user@example.com",
      subject: "Welcome",
      body: "Welcome to our service"
    )

    assert_equal "noreply@example.com", result[:from]
    assert_equal "user@example.com", result[:to]
  end

  def test_partial_application_reuse
    send_email = SendEmailOperation.with(from: "noreply@example.com")

    result1 = send_email.call(to: "user1@example.com", subject: "Test", body: "Body")
    result2 = send_email.call(to: "user2@example.com", subject: "Test", body: "Body")

    assert_equal "user1@example.com", result1[:to]
    assert_equal "user2@example.com", result2[:to]
  end

  class AddOperation < TypedOperation::Base
    positional_param :a, Integer
    positional_param :b, Integer

    def perform
      a + b
    end
  end

  def test_currying_basic
    curried = AddOperation.curry
    result = curried.call(5).call(3)
    assert_equal 8, result
  end

  def test_currying_with_partial_application
    curried = AddOperation.curry
    add_five = curried.call(5)

    assert_equal 8, add_five.call(3)
    assert_equal 10, add_five.call(5)
  end

  class NotificationOperation < TypedOperation::Base
    param :template, String
    param :recipient, String
    param :priority, String

    def perform
      { template: template, recipient: recipient, priority: priority }
    end
  end

  def test_chaining_partial_applications
    base = NotificationOperation.with(template: "welcome")
    high_priority = base.with(priority: "high")

    result = high_priority.call(recipient: "user@example.com")

    assert_equal "welcome", result[:template]
    assert_equal "user@example.com", result[:recipient]
    assert_equal "high", result[:priority]
  end

  def test_partially_applied_returns_correct_class
    partial = SendEmailOperation.with(from: "test@example.com")

    assert_kind_of TypedOperation::PartiallyApplied, partial
  end

  def test_prepared_returns_correct_class
    prepared = SendEmailOperation.with(
      from: "test@example.com",
      to: "user@example.com",
      subject: "Test",
      body: "Body"
    )

    assert_kind_of TypedOperation::Prepared, prepared
    assert prepared.prepared?
  end
end
