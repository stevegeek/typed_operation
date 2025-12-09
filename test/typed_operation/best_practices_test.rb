# frozen_string_literal: true

require "test_helper"

class BestPracticesTest < Minitest::Test
  class ValidateDataOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :data, Hash

    def perform
      return Failure(:empty_data) if data.empty?

      Success(data)
    end
  end

  class TransformDataOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :data, Hash

    def perform
      Success(data.transform_keys(&:to_s))
    end
  end

  class ProcessDataOperation < TypedOperation::Base
    include Dry::Monads[:result]
    include Dry::Monads::Do.for(:perform)

    param :data, Hash

    def perform
      validated = yield ValidateDataOperation.call(data: data)
      transformed = yield TransformDataOperation.call(data: validated)

      Success(transformed)
    end
  end

  def test_composed_operations_success
    result = ProcessDataOperation.call(data: {name: "Test"})

    assert result.success?
    assert_equal({"name" => "Test"}, result.value!)
  end

  def test_composed_operations_failure
    result = ProcessDataOperation.call(data: {})

    assert result.failure?
    assert_equal :empty_data, result.failure
  end

  class FormatMessageOperation < TypedOperation::Base
    param :prefix, String
    param :message, String

    def perform
      "#{prefix}: #{message}"
    end
  end

  def test_partial_application_pipeline
    error_formatter = FormatMessageOperation.with(prefix: "ERROR")
    warning_formatter = FormatMessageOperation.with(prefix: "WARNING")

    assert_equal "ERROR: Something failed", error_formatter.call(message: "Something failed")
    assert_equal "WARNING: Check this", warning_formatter.call(message: "Check this")
  end

  class CoerceParamsOperation < TypedOperation::Base
    param :count, Integer, &:to_i
    param :enabled, _Boolean

    def perform
      {count: count, enabled: enabled}
    end
  end

  def test_parameter_coercion
    result = CoerceParamsOperation.call(count: "42", enabled: true)

    assert_equal 42, result[:count]
    assert_kind_of Integer, result[:count]
  end

  class SearchOperation < TypedOperation::Base
    include Literal::Types

    param :query, String
    param :limit, Integer, default: 25
    param :offset, Integer, default: 0
    param :sort_by, optional(String)

    def perform
      {
        query: query,
        limit: limit,
        offset: offset,
        sort_by: sort_by || :created_at
      }
    end
  end

  def test_optional_parameters_defaults
    result = SearchOperation.call(query: "test")

    assert_equal "test", result[:query]
    assert_equal 25, result[:limit]
    assert_equal 0, result[:offset]
    assert_equal :created_at, result[:sort_by]
  end

  def test_optional_parameters_custom_values
    result = SearchOperation.call(
      query: "test",
      limit: 50,
      offset: 100,
      sort_by: "name"
    )

    assert_equal 50, result[:limit]
    assert_equal 100, result[:offset]
    assert_equal "name", result[:sort_by]
  end

  class ApplyDiscountOperation < TypedOperation::Base
    include Dry::Monads[:result]

    param :amount, Integer
    param :discount_percent, Integer

    def perform
      discounted = amount - (amount * discount_percent / 100)
      Success(discounted)
    end
  end

  class CalculateTotalOperation < TypedOperation::Base
    include Dry::Monads[:result]
    include Dry::Monads::Do.for(:perform)

    param :amount, Integer
    param :apply_discount, _Boolean, default: false
    param :discount_percent, Integer, default: 0

    def perform
      total = amount

      if apply_discount && discount_percent > 0
        total = yield ApplyDiscountOperation.call(
          amount: total,
          discount_percent: discount_percent
        )
      end

      Success(total)
    end
  end

  def test_conditional_composition_with_discount
    result = CalculateTotalOperation.call(
      amount: 100,
      apply_discount: true,
      discount_percent: 10
    )

    assert result.success?
    assert_equal 90, result.value!
  end

  def test_conditional_composition_without_discount
    result = CalculateTotalOperation.call(amount: 100)

    assert result.success?
    assert_equal 100, result.value!
  end

  class BuildConfigOperation < TypedOperation::Base
    param :environment, String
    param :debug, _Boolean, default: false
    param :timeout, Integer, default: 30

    def perform
      {
        environment: environment,
        debug: debug,
        timeout: timeout
      }
    end
  end

  def test_builder_pattern
    base_config = BuildConfigOperation.with(environment: "production")
    debug_config = base_config.with(debug: true)

    prod_result = base_config.call(timeout: 60)
    debug_result = debug_config.call(timeout: 30)

    assert_equal "production", prod_result[:environment]
    refute prod_result[:debug]
    assert_equal 60, prod_result[:timeout]

    assert_equal "production", debug_result[:environment]
    assert debug_result[:debug]
    assert_equal 30, debug_result[:timeout]
  end
end
