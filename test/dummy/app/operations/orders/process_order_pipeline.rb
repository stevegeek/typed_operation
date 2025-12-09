# frozen_string_literal: true

module Orders
  # Pipeline DSL example for multi-step order processing.
  ProcessOrderPipeline = TypedOperation::Pipeline.build do
    step :validate, ValidateOrderParams
    step :check_stock, CheckProductStock, if: ->(ctx) { !ctx[:skip_stock_check] }
    transform do |ctx|
      ctx.merge(total: ctx[:product].price * ctx[:quantity])
    end
    step :create_order, CreateOrderRecord
  end
end
