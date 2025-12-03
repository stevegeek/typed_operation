# frozen_string_literal: true

module TypedOperation
  # Context objects are for passing data through pipelines and chains.
  #
  # This particular implementation wraps a Hash but provides dot access for cleaner syntax.
  # Its underlying store is mutable.
  #
  # Users can subclass or provide their own context that implements the same interface.
  #
  # Required interface for custom contexts:
  #   - #[](key)        - read a value
  #   - #[]=(key, value) - write a value (if mutable)
  #   - #key?(key)      - check if key exists
  #   - #to_h           - convert to Hash (for kwargs extraction)
  #   - #merge(other)   - combine with another context/hash, returns new context
  #
  # Dot access is not required. It's up to you if you prefer to have it in your operation usage.
  #
  class Context
    # Create a new context from a hash or another context.
    def initialize(data = {})
      @data = coerce_to_hash(data).transform_keys(&:to_sym)
    end

    # Read a value by key.
    def [](key)
      read_value(key.to_sym)
    end

    # Write a value by key.
    def []=(key, value)
      write_value(key.to_sym, value)
    end

    # Check if a key exists.
    def key?(key)
      @data.key?(key.to_sym)
    end
    alias_method :has_key?, :key?

    # Convert to a Hash.
    def to_h
      @data.dup
    end
    alias_method :to_hash, :to_h

    # Merge with another context or hash, returning a new Context.
    def merge(other)
      self.class.new(@data.merge(coerce_to_hash(other)))
    end

    # Fetch a value with a default or block.
    def fetch(key, *args, &block)
      @data.fetch(key.to_sym, *args, &block)
    end

    # Get all keys.
    def keys
      @data.keys
    end

    # Get all values.
    def values
      @data.values
    end

    # Iterate over key-value pairs.
    def each(&block)
      return enum_for(:each) unless block_given?
      @data.each(&block)
      self
    end

    # Select entries matching a condition.
    def select(&block)
      self.class.new(@data.select(&block))
    end

    # Reject entries matching a condition.
    def reject(&block)
      self.class.new(@data.reject(&block))
    end

    # Transform values.
    def transform_values(&block)
      self.class.new(@data.transform_values(&block))
    end

    # Slice to only the specified keys.
    def slice(*keys)
      self.class.new(@data.slice(*keys.map(&:to_sym)))
    end

    # Get subset excluding specified keys.
    def except(*keys)
      self.class.new(@data.except(*keys.map(&:to_sym)))
    end

    # Check if context is empty.
    def empty?
      @data.empty?
    end

    # Get the number of entries.
    def size
      @data.size
    end
    alias_method :length, :size

    # Equality check.
    def ==(other)
      case other
      when Context
        @data == other.to_h
      when Hash
        @data == other.transform_keys(&:to_sym)
      else
        false
      end
    end

    # Provide dot access for reading and writing values.
    def method_missing(name, *args, &block)
      name_str = name.to_s

      if name_str.end_with?("=")
        # Setter: ctx.foo = value
        key = name_str.chomp("=").to_sym
        write_value(key, args.first)
      elsif name_str.end_with?("?")
        # Predicate: ctx.validated?
        key = name_str.chomp("?").to_sym
        !!read_value(key)
      elsif args.empty? && !block
        # Getter: ctx.foo
        read_value(name)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      name_str = name.to_s
      name_str.end_with?("=", "?") ||
        key?(name) ||
        super
    end

    # String representation for debugging.
    def inspect
      "#<#{self.class.name} #{@data.inspect}>"
    end

    alias_method :to_s, :inspect

    private

    # Read a value from the underlying data store.
    # Override this in subclasses to customize read behavior (e.g., lazy loading).
    def read_value(key)
      @data[key]
    end

    # Write a value to the underlying data store.
    # Override this in subclasses to customize write behavior (e.g., validation).
    def write_value(key, value)
      @data[key] = value
    end

    def coerce_to_hash(obj)
      case obj
      when Hash
        obj
      when Context
        obj.to_h
      when ->(o) { o.respond_to?(:to_h) }
        obj.to_h
      else
        raise ArgumentError, "Cannot coerce #{obj.class} to Hash"
      end
    end
  end
end
