# frozen_string_literal: true

class ApplicationOperation < ::TypedOperation::Base
<% if include_dry_monads? -%>
  include Dry::Monads[:result, :do]

  def call!
    call.value!
  end

<% end -%>
  # Other common parameters & methods for Operations of this application...
  # ...
end
