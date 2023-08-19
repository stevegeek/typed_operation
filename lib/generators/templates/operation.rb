# frozen_string_literal: true

<% if namespace_name.present? %>
module <%= namespace_name %>
  class <%= name %> < ::ApplicationOperation
    # Replace with implementation...
    positional :required_positional_param, String
    named :required_named_param, String
    named :an_optional_param, Integer, optional: true do |value|
     value.to_i
    end

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
  positional :required_positional_param, String
  named :required_named_param, String
  named :an_optional_param, Integer, optional: true do |value|
    value.to_i
  end

  def prepare
    # Prepare...
  end

  def call
    # Perform...
    "Hello World!"
  end
end
<% end %>
