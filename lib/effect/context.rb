# frozen_string_literal: true

module Effect
  # Context models the fiber-local environment Thread used for dependency injection.
  class Context
    attr_reader :values

    def initialize(values = {})
      @values = values.freeze
    end

    def self.empty
      @empty ||= new
    end

    def self.current
      store = local_store
      store[:effect_context] ||= empty
    end

    def self.with(context)
      store = local_store
      previous = store[:effect_context] || empty
      store[:effect_context] = context
      yield
    ensure
      store[:effect_context] = previous
    end

    def self.provide(key, value)
      with(current.provide(key, value)) { yield }
    end

    def [](key)
      @values[key]
    end

    def fetch(key)
      return @values.fetch(key) if @values.key?(key)

      raise KeyError, "missing context value for #{key.inspect}"
    end

    def provide(key, value)
      Context.new(@values.merge(key => value))
    end

    def merge(other)
      case other
      when Context
        Context.new(@values.merge(other.values))
      when Hash
        Context.new(@values.merge(other))
      else
        raise ArgumentError, "cannot merge context with #{other.class}"
      end
    end

    def to_h
      @values.dup
    end

    def self.local_store
      fiber = defined?(Fiber) && Fiber.respond_to?(:current) ? Fiber.current : nil
      if fiber && fiber.respond_to?(:[]) && fiber.respond_to?(:[]=)
        fiber
      else
        Thread.current
      end
    end
    private_class_method :local_store
  end
end
