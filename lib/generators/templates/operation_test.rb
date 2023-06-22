# frozen_string_literal: true

<% if namespace_name.present? %>
module <%= namespace_name %>
  class <%= name %>Test < ActiveSupport::TestCase
    def setup
      @operation = <%= name %>.new(my_param: "test")
    end

    test 'should raise ParameterError if my_param is nil' do
      assert_raises(ParameterError) do
        <%= name %>.new(my_param: nil)
      end
    end

    test 'should convert my_param if it is not a string' do
      assert_equal <%= name %>.new(my_param: 123).my_param, "123"
    end

    test 'call returns after operation' do
      result = @operation.call
      assert_equal result, "Hello World!"
    end
  end
end
<% else %>
  class <%= name %>Test < ActiveSupport::TestCase
    def setup
      @operation = <%= name %>.new(my_param: "test")
    end

    test 'should raise ParameterError if my_param is nil' do
      assert_raises(ParameterError) do
        <%= name %>.new(my_param: nil)
      end
    end

    test 'should convert my_param if it is not a string' do
      assert_equal <%= name %>.new(my_param: 123).my_param, "123"
  end

  test 'call returns after operation' do
    result = @operation.call
    assert_equal result, "Hello World!"
  end
end
<% end %>
