# frozen_string_literal: true

require "test_helper"
require "date"

# Tests for examples from error-handling.md
class ErrorHandlingTest < Minitest::Test
  # Custom exception classes
  class TransferOperation < TypedOperation::Base
    class InsufficientFundsError < StandardError; end
    class AccountFrozenError < StandardError; end

    param :from_balance, Integer
    param :to_balance, Integer
    param :amount, Integer
    param :frozen, _Boolean, default: false

    def perform
      raise InsufficientFundsError if from_balance < amount
      raise AccountFrozenError if frozen

      {
        from: from_balance - amount,
        to: to_balance + amount
      }
    end
  end

  def test_insufficient_funds_error
    error = assert_raises TransferOperation::InsufficientFundsError do
      TransferOperation.call(from_balance: 100, to_balance: 0, amount: 200)
    end

    assert_kind_of TransferOperation::InsufficientFundsError, error
  end

  def test_account_frozen_error
    error = assert_raises TransferOperation::AccountFrozenError do
      TransferOperation.call(from_balance: 200, to_balance: 0, amount: 100, frozen: true)
    end

    assert_kind_of TransferOperation::AccountFrozenError, error
  end

  def test_successful_transfer
    result = TransferOperation.call(from_balance: 200, to_balance: 50, amount: 100)

    assert_equal 100, result[:from]
    assert_equal 150, result[:to]
  end

  # Validation in prepare hook
  class UpdateProfileOperation < TypedOperation::Base
    class InvalidUrlError < StandardError; end

    param :bio, String
    param :website, String

    def prepare
      raise InvalidUrlError, "Invalid URL format" unless website.start_with?("http")
      raise ArgumentError, "Bio too long" if bio.length > 500
    end

    def perform
      { bio: bio, website: website }
    end
  end

  def test_prepare_hook_url_validation
    error = assert_raises UpdateProfileOperation::InvalidUrlError do
      UpdateProfileOperation.call(bio: "Test", website: "invalid")
    end

    assert_equal "Invalid URL format", error.message
  end

  def test_prepare_hook_bio_validation
    assert_raises ArgumentError do
      UpdateProfileOperation.call(bio: "x" * 501, website: "https://example.com")
    end
  end

  def test_prepare_hook_success
    result = UpdateProfileOperation.call(bio: "Test bio", website: "https://example.com")

    assert_equal "Test bio", result[:bio]
    assert_equal "https://example.com", result[:website]
  end

  # Result types for expected failures
  class ProcessPaymentOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :balance, Integer
    param :amount, Integer
    param :card_expired, _Boolean, default: false

    def perform
      return Failure([:insufficient_funds, "Balance too low"]) if balance < amount
      return Failure([:invalid_card, "Card expired"]) if card_expired

      Success(balance - amount)
    end
  end

  def test_result_insufficient_funds
    result = ProcessPaymentOperation.call(balance: 50, amount: 100)

    assert result.failure?
    code, message = result.failure
    assert_equal :insufficient_funds, code
    assert_equal "Balance too low", message
  end

  def test_result_card_expired
    result = ProcessPaymentOperation.call(balance: 100, amount: 50, card_expired: true)

    assert result.failure?
    code, message = result.failure
    assert_equal :invalid_card, code
  end

  def test_result_success
    result = ProcessPaymentOperation.call(balance: 100, amount: 50)

    assert result.success?
    assert_equal 50, result.value!
  end

  # Combining exceptions and results
  class BookingOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :start_date, Date
    param :end_date, Date
    param :room_available, _Boolean, default: true

    def prepare
      raise ArgumentError, "End date must be after start date" if end_date <= start_date
      raise ArgumentError, "Booking must be in the future" if start_date < Date.today
    end

    def perform
      return Failure(:room_unavailable) unless room_available

      Success({ start_date: start_date, end_date: end_date })
    end
  end

  def test_booking_prepare_validation
    assert_raises ArgumentError do
      BookingOperation.call(
        start_date: Date.today,
        end_date: Date.today - 1,
        room_available: true
      )
    end
  end

  def test_booking_business_failure
    result = BookingOperation.call(
      start_date: Date.today + 1,
      end_date: Date.today + 2,
      room_available: false
    )

    assert result.failure?
    assert_equal :room_unavailable, result.failure
  end

  def test_booking_success
    result = BookingOperation.call(
      start_date: Date.today + 1,
      end_date: Date.today + 2,
      room_available: true
    )

    assert result.success?
    assert_equal Date.today + 1, result.value![:start_date]
  end

  # Wrapping exceptions in results
  class FetchDataOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :id, Integer
    param :simulate_error, Symbol, default: :none

    def perform
      raise StandardError, "Not found" if simulate_error == :not_found
      raise StandardError, "Connection failed" if simulate_error == :connection

      Success({ id: id, data: "Data for #{id}" })
    rescue => e
      code = simulate_error == :not_found ? :not_found : :database_error
      Failure([code, e.message])
    end
  end

  def test_wrapping_exception_not_found
    result = FetchDataOperation.call(id: 1, simulate_error: :not_found)

    assert result.failure?
    code, message = result.failure
    assert_equal :not_found, code
    assert_equal "Not found", message
  end

  def test_wrapping_exception_connection
    result = FetchDataOperation.call(id: 1, simulate_error: :connection)

    assert result.failure?
    code, _message = result.failure
    assert_equal :database_error, code
  end

  def test_wrapping_exception_success
    result = FetchDataOperation.call(id: 1)

    assert result.success?
    assert_equal 1, result.value![:id]
  end
end
