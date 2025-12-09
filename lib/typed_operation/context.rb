# rbs_inline: enabled
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
    # @rbs @data: Hash[Symbol, untyped]

    #: (?Hash[Symbol | String, untyped] | Context | _ToH) -> void
    def initialize(data = {})
      @data = coerce_to_hash(data).transform_keys(&:to_sym)
    end

    #: (Symbol | String) -> untyped
    def [](key)
      read_value(key.to_sym)
    end

    #: (Symbol | String, untyped) -> untyped
    def []=(key, value)
      write_value(key.to_sym, value)
    end

    #: (Symbol | String) -> bool
    def key?(key)
      @data.key?(key.to_sym)
    end
    alias_method :has_key?, :key?

    #: () -> Hash[Symbol, untyped]
    def to_h
      @data.dup
    end
    alias_method :to_hash, :to_h

    #: (Hash[Symbol | String, untyped] | Context | _ToH) -> Context
    def merge(other)
      self.class.new(@data.merge(coerce_to_hash(other)))
    end

    #: (Symbol | String) -> untyped
    #: [T] (Symbol | String, T) -> (untyped | T)
    #: [T] (Symbol | String) { (Symbol) -> T } -> (untyped | T)
    def fetch(key, *args, &block)
      @data.fetch(key.to_sym, *args, &block)
    end

    #: () -> Array[Symbol]
    def keys
      @data.keys
    end

    #: () -> Array[untyped]
    def values
      @data.values
    end

    #: () -> Enumerator[[Symbol, untyped], self]
    #: () { ([Symbol, untyped]) -> void } -> self
    def each(&block)
      return enum_for(:each) unless block_given?
      @data.each(&block)
      self
    end

    #: () { (Symbol, untyped) -> boolish } -> Context
    def select(&block)
      self.class.new(@data.select(&block))
    end

    #: () { (Symbol, untyped) -> boolish } -> Context
    def reject(&block)
      self.class.new(@data.reject(&block))
    end

    #: () { (untyped) -> untyped } -> Context
    def transform_values(&block)
      self.class.new(@data.transform_values(&block))
    end

    #: (*(Symbol | String)) -> Context
    def slice(*keys)
      self.class.new(@data.slice(*keys.map(&:to_sym)))
    end

    #: (*(Symbol | String)) -> Context
    def except(*keys)
      self.class.new(@data.except(*keys.map(&:to_sym)))
    end

    #: () -> bool
    def empty?
      @data.empty?
    end

    #: () -> Integer
    def size
      @data.size
    end
    alias_method :length, :size

    #: (untyped) -> bool
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
    #: (Symbol, *untyped) ?{ (*untyped) -> untyped } -> untyped
    def method_missing(name, *args, &block)
      name_str = name.to_s

      if name_str.end_with?("=")
        key = name_str.chomp("=").to_sym
        write_value(key, args.first)
      elsif name_str.end_with?("?")
        key = name_str.chomp("?").to_sym
        !!read_value(key)
      elsif args.empty? && !block
        read_value(name)
      else
        super
      end
    end

    #: (Symbol, ?bool) -> bool
    def respond_to_missing?(name, include_private = false)
      name_str = name.to_s
      name_str.end_with?("=", "?") ||
        key?(name) ||
        super
    end

    #: () -> String
    def inspect
      "#<#{self.class.name} #{@data.inspect}>"
    end

    alias_method :to_s, :inspect

    private

    #: (Symbol) -> untyped
    def read_value(key)
      @data[key]
    end

    #: (Symbol, untyped) -> untyped
    def write_value(key, value)
      @data[key] = value
    end

    # @rbs!
    #   interface _ToH
    #     def to_h: () -> Hash[untyped, untyped]
    #   end

    #: (untyped) -> Hash[untyped, untyped]
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
