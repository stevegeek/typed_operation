# frozen_string_literal: true

<% if namespace_name.present? %>
module <%= namespace_name %>
  class <%= name %> < ::ApplicationOperation
    # Replace with implementation...
    param :param1, String, convert: true

    def prepare
      # Prepare...
    end

    def call
      # Perform...
    end
  end
end
<% else %>
class <%= name %> < ::ApplicationOperation
  # Replace with implementation...
  param :param1, String, convert: true

  def prepare
    # Prepare...
  end

  def call
    # Perform...
  end
end
<% end %>
