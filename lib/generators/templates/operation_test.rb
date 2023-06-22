# frozen_string_literal: true

require "test_helper"

<% if namespace_name.present? %>
module <%= namespace_name %>
  class <%= name %>Test < ActiveSupport::TestCase
    def setup
      @operation = <%= name %>.new(required_param: "test")
    end

    test "should raise ParameterError if required param is nil" do
      assert_raises(ParameterError) do
        <%= name %>.new(required_param: nil)
      end
    end

    test "should convert optional_param if it is not a string" do
      assert_equal <%= name %>.new(required_param: "foo", optional_param: 123).converts_param, "123"
    end

    test "call returns after operation" do
      result = @operation.call
      assert_equal result, "Hello World!"
    end
  end
end
<% else %>
class <%= name %>Test < ActiveSupport::TestCase
  def setup
    @operation = <%= name %>.new(required_param: "test")
  end

  test "should raise ParameterError if required param is nil" do
    assert_raises(ParameterError) do
      <%= name %>.new(required_param: nil)
    end
  end

  test "should convert optional_param if it is not a string" do
    assert_equal <%= name %>.new(required_param: "foo", optional_param: 123).converts_param, "123"
  end

  test "call returns after operation" do
    result = @operation.call
    assert_equal result, "Hello World!"
  end
end
<% end %>
