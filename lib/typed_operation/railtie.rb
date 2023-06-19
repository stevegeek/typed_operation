module TypedOperation
  class Railtie < ::Rails::Railtie
    generators do
      require "generators/typed_operation/install/install_generator"
      require "generators/typed_operation_generator"
    end
  end
end
