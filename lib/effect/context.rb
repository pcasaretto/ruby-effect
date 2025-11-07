# typed: true

module Effect
  class Context
    extend T::Sig

    THREAD_KEY = :__effect_runtime_context

    def self.empty
      @empty ||= new({})
    end

    def self.from_hash(entries)
      new(entries)
    end

    def self.current
      Thread.current[THREAD_KEY] || empty
    end

    def self.use(context)
      previous = Thread.current[THREAD_KEY]
      Thread.current[THREAD_KEY] = context
      yield
    ensure
      Thread.current[THREAD_KEY] = previous
    end

    sig { returns(T::Hash[DependencyKey, T.untyped]) }
    attr_reader :entries

    sig { params(entries: T::Hash[T.any(DependencyKey, Symbol, String), T.untyped]).void }
    def initialize(entries)
      coerced = entries.each_with_object({}) do |(key, value), memo|
        dep_key = DependencyKey === key ? key : DependencyKey.new(key)
        memo[dep_key] = value
      end
      @entries = T.let(coerced.freeze, T::Hash[DependencyKey, T.untyped])
    end

    sig do
      params(
        key: DependencyKey,
        block: T.nilable(T.proc.params(arg0: DependencyKey).returns(T.untyped))
      ).returns(T.untyped)
    end
    def fetch(key, &block)
      if entries.key?(key)
        entries[key]
      elsif block
        block.call(key)
      else
        raise KeyError, "Missing context key: #{key.name}"
      end
    end

    sig { params(key: T.any(DependencyKey, Symbol, String)).returns(T::Boolean) }
    def key?(key)
      entries.key?(normalize_key(key))
    end

    sig { params(key: T.any(DependencyKey, Symbol, String), value: T.untyped).returns(Context) }
    def with(key, value)
      normalized = normalize_key(key)
      self.class.new(entries.merge(normalized => value))
    end

    def merge(other)
      case other
      when Context
        self.class.new(entries.merge(other.entries))
      when Hash
        additions = other.transform_keys { |key| normalize_key(key) }
        self.class.new(entries.merge(additions))
      else
        raise ArgumentError, "Cannot merge #{other.class} into Context"
      end
    end

    def to_h
      entries.dup
    end

    private

    sig { params(key: T.any(DependencyKey, Symbol, String)).returns(DependencyKey) }
    def normalize_key(key)
      return key if key.is_a?(DependencyKey)

      DependencyKey.new(key)
    end
  end
end
