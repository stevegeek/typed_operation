# frozen_string_literal: true

<% if namespace_name.present? %>
module <%= namespace_name %>
  class <%= name %> < ::ApplicationOperation
    # Replace with implementation...
    positional_param :required_positional_param, String
    param :required_named_param, String
    param :an_optional_param, Integer, optional: true do |value|
     value.to_i
    end

    def prepare
      # Prepare...
    end

    def perform
      # Perform...
      "Hello World!"
    end
  end
end
<% else %>
class <%= name %> < ::ApplicationOperation
  # Replace with implementation...
  positional_param :required_positional_param, String
  param :required_named_param, String
  param :an_optional_param, Integer, optional: true do |value|
    value.to_i
  end

  def prepare
    # Prepare...
  end

  def perform
    # Perform...
    "Hello World!"
  end
end
<% end %>
