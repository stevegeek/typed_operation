# frozen_string_literal: true

require "test_helper"

class ContextTest < Minitest::Test
  def test_initialize_with_hash
    ctx = TypedOperation::Context.new(name: "Alice", age: 30)

    assert_equal "Alice", ctx[:name]
    assert_equal 30, ctx[:age]
  end

  def test_initialize_with_string_keys_converts_to_symbols
    ctx = TypedOperation::Context.new("name" => "Alice", "age" => 30)

    assert_equal "Alice", ctx[:name]
    assert_equal 30, ctx[:age]
  end

  def test_initialize_empty
    ctx = TypedOperation::Context.new

    assert ctx.empty?
    assert_equal({}, ctx.to_h)
  end

  def test_initialize_from_another_context
    original = TypedOperation::Context.new(foo: "bar")
    copy = TypedOperation::Context.new(original)

    assert_equal "bar", copy[:foo]
  end

  def test_hash_style_read
    ctx = TypedOperation::Context.new(user: "bob")

    assert_equal "bob", ctx[:user]
    assert_nil ctx[:nonexistent]
  end

  def test_hash_style_write
    ctx = TypedOperation::Context.new

    ctx[:name] = "Carol"

    assert_equal "Carol", ctx[:name]
  end

  def test_dot_access_read
    ctx = TypedOperation::Context.new(user: "bob", amount: 42)

    assert_equal "bob", ctx.user
    assert_equal 42, ctx.amount
    assert_nil ctx.nonexistent
  end

  def test_dot_access_write
    ctx = TypedOperation::Context.new

    ctx.name = "Carol"
    ctx.active = true

    assert_equal "Carol", ctx.name
    assert_equal true, ctx.active
  end

  def test_predicate_methods
    ctx = TypedOperation::Context.new(active: true, disabled: false, name: "test")

    assert ctx.active?
    refute ctx.disabled?
    assert ctx.name?
    refute ctx.missing?
  end

  def test_key_check
    ctx = TypedOperation::Context.new(present: "yes")

    assert ctx.key?(:present)
    assert ctx.has_key?(:present)
    refute ctx.key?(:missing)
  end

  def test_to_h_returns_copy
    ctx = TypedOperation::Context.new(a: 1)
    hash = ctx.to_h

    hash[:b] = 2

    refute ctx.key?(:b)
  end

  def test_to_hash_alias
    ctx = TypedOperation::Context.new(a: 1)

    assert_equal ctx.to_h, ctx.to_hash
  end

  def test_merge_returns_new_context
    ctx1 = TypedOperation::Context.new(a: 1, b: 2)
    ctx2 = ctx1.merge(b: 3, c: 4)

    assert_equal 2, ctx1[:b]
    assert_equal 3, ctx2[:b]
    assert_equal 4, ctx2[:c]
    refute ctx1.key?(:c)
  end

  def test_merge_with_hash
    ctx = TypedOperation::Context.new(a: 1)
    merged = ctx.merge({b: 2})

    assert_equal 1, merged[:a]
    assert_equal 2, merged[:b]
  end

  def test_merge_with_context
    ctx1 = TypedOperation::Context.new(a: 1)
    ctx2 = TypedOperation::Context.new(b: 2)
    merged = ctx1.merge(ctx2)

    assert_equal 1, merged[:a]
    assert_equal 2, merged[:b]
  end

  def test_fetch_with_default
    ctx = TypedOperation::Context.new(present: "yes")

    assert_equal "yes", ctx.fetch(:present)
    assert_equal "default", ctx.fetch(:missing, "default")
  end

  def test_fetch_with_block
    ctx = TypedOperation::Context.new

    result = ctx.fetch(:missing) { "computed" }

    assert_equal "computed", result
  end

  def test_fetch_raises_without_default
    ctx = TypedOperation::Context.new

    assert_raises(KeyError) { ctx.fetch(:missing) }
  end

  def test_keys
    ctx = TypedOperation::Context.new(a: 1, b: 2)

    assert_equal [:a, :b], ctx.keys.sort
  end

  def test_values
    ctx = TypedOperation::Context.new(a: 1, b: 2)

    assert_equal [1, 2], ctx.values.sort
  end

  def test_each
    ctx = TypedOperation::Context.new(a: 1, b: 2)
    pairs = []

    ctx.each { |k, v| pairs << [k, v] }

    assert_includes pairs, [:a, 1]
    assert_includes pairs, [:b, 2]
  end

  def test_each_returns_enumerator_without_block
    ctx = TypedOperation::Context.new(a: 1)

    assert_kind_of Enumerator, ctx.each
  end

  def test_select
    ctx = TypedOperation::Context.new(a: 1, b: 2, c: 3)
    selected = ctx.select { |_k, v| v > 1 }

    assert_kind_of TypedOperation::Context, selected
    assert_equal({b: 2, c: 3}, selected.to_h)
  end

  def test_reject
    ctx = TypedOperation::Context.new(a: 1, b: 2, c: 3)
    rejected = ctx.reject { |_k, v| v > 1 }

    assert_kind_of TypedOperation::Context, rejected
    assert_equal({a: 1}, rejected.to_h)
  end

  def test_transform_values
    ctx = TypedOperation::Context.new(a: 1, b: 2)
    transformed = ctx.transform_values { |v| v * 10 }

    assert_kind_of TypedOperation::Context, transformed
    assert_equal({a: 10, b: 20}, transformed.to_h)
  end

  def test_slice
    ctx = TypedOperation::Context.new(a: 1, b: 2, c: 3)
    sliced = ctx.slice(:a, :c)

    assert_kind_of TypedOperation::Context, sliced
    assert_equal({a: 1, c: 3}, sliced.to_h)
  end

  def test_except
    ctx = TypedOperation::Context.new(a: 1, b: 2, c: 3)
    excepted = ctx.except(:b)

    assert_kind_of TypedOperation::Context, excepted
    assert_equal({a: 1, c: 3}, excepted.to_h)
  end

  def test_empty
    assert TypedOperation::Context.new.empty?
    refute TypedOperation::Context.new(a: 1).empty?
  end

  def test_size
    ctx = TypedOperation::Context.new(a: 1, b: 2, c: 3)

    assert_equal 3, ctx.size
    assert_equal 3, ctx.length
  end

  def test_equality_with_context
    ctx1 = TypedOperation::Context.new(a: 1, b: 2)
    ctx2 = TypedOperation::Context.new(a: 1, b: 2)
    ctx3 = TypedOperation::Context.new(a: 1, b: 3)

    assert_equal ctx1, ctx2
    refute_equal ctx1, ctx3
  end

  def test_equality_with_hash
    ctx = TypedOperation::Context.new(a: 1, b: 2)

    assert_equal ctx, {a: 1, b: 2}
    assert_equal ctx, {"a" => 1, "b" => 2}
    refute_equal ctx, {a: 1}
  end

  def test_inspect
    ctx = TypedOperation::Context.new(name: "test")

    assert_match(/Context/, ctx.inspect)
    assert_match(/name/, ctx.inspect)
  end

  def test_respond_to
    ctx = TypedOperation::Context.new(existing: true)

    assert ctx.respond_to?(:[])
    assert ctx.respond_to?(:[]=)
    assert ctx.respond_to?(:to_h)
    assert ctx.respond_to?(:merge)
    assert ctx.respond_to?(:existing)
    assert ctx.respond_to?(:existing?)
    assert ctx.respond_to?(:anything=)
  end

  def test_can_be_used_as_kwargs_splat
    ctx = TypedOperation::Context.new(name: "Alice", age: 30)

    def receiver(name:, age:)
      "#{name} is #{age}"
    end

    result = receiver(**ctx.to_h)

    assert_equal "Alice is 30", result
  end

  def test_subclass_preserves_type_on_merge
    custom_class = Class.new(TypedOperation::Context) do
      def custom_method
        "custom"
      end
    end

    ctx = custom_class.new(a: 1)
    merged = ctx.merge(b: 2)

    assert_kind_of custom_class, merged
    assert_equal "custom", merged.custom_method
  end

  def test_subclass_can_override_read_value
    custom_class = Class.new(TypedOperation::Context) do
      private

      def read_value(key)
        if key == :user && !@data.key?(:user)
          @data[:user] = "default_user"
        end
        super
      end
    end

    ctx = custom_class.new
    assert_equal "default_user", ctx[:user]
    assert_equal "default_user", ctx.user

    ctx2 = custom_class.new(user: "custom")
    assert_equal "custom", ctx2[:user]
    assert_equal "custom", ctx2.user
  end

  def test_subclass_can_override_write_value
    custom_class = Class.new(TypedOperation::Context) do
      private

      def write_value(key, value)
        if key == :name
          super(key, value.to_s.upcase)
        else
          super
        end
      end
    end

    ctx = custom_class.new
    ctx[:name] = "alice"
    assert_equal "ALICE", ctx[:name]

    ctx.title = "developer"
    assert_equal "developer", ctx[:title]
  end
end
