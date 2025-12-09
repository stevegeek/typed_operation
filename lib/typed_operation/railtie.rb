# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Rails integration for TypedOperation, registers generators.
  class Railtie < ::Rails::Railtie
    generators do
      require "generators/typed_operation/install/install_generator"
      require "generators/typed_operation_generator"
    end
  end
end
