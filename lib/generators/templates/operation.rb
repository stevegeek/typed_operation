# frozen_string_literal: true

<% if namespace_name.present? %>
module <%= namespace_name %>
  class <%= name %> < ::ApplicationOperation
    # Replace with implementation...
    param :my_param, String, convert: true
    param :an_optional_param, Integer, allow_nil: true

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
  param :my_param, String, convert: true
  param :an_optional_param, Integer, allow_nil: true

  def prepare
    # Prepare...
  end

  def call
    # Perform...
    "Hello World!"
  end
end
<% end %>
