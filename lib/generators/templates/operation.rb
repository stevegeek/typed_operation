# frozen_string_literal: true

<% if namespace_name.present? %>
module <%= namespace_name %>
  class <%= name %> < ::ApplicationOperation
    # Replace with implementation...
    param :required_param, String
    param :an_optional_param, Integer, convert: true, allow_nil: true

    def prepare
      # Prepare...
    end

    def call
      # Perform...
      "Hello World!"
    end
  end
end
<% else %>
class <%= name %> < ::ApplicationOperation
  # Replace with implementation...
  param :required_param, String
  param :an_optional_param, Integer, convert: true, allow_nil: true

  def prepare
    # Prepare...
  end

  def call
    # Perform...
    "Hello World!"
  end
end
<% end %>
