# typed: true

module Effect
  class DependencyKey
    extend T::Generic
    Value = type_member(:out)

    sig { params(name: Symbol, type: T.untyped).void }
    def initialize(name, type: T.untyped = T.unsafe(nil)); end

    sig { returns(Symbol) }
    def name; end

    sig { returns(T.untyped) }
    def type; end
  end

  module Keys
    extend T::Sig

    sig { params(name: Symbol, type: T.untyped).returns(DependencyKey[T.untyped]) }
    def self.define(name, type: T.untyped); end
  end

  class Cause
    extend T::Sig

    sig { returns(Symbol) }
    def tag; end

    sig { returns(T.nilable(String)) }
    def message; end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def metadata; end
  end

  class FailureError < StandardError
    extend T::Sig

    sig { returns(Cause) }
    def cause; end
  end

  class Result
    extend T::Generic
    extend T::Sig

    Error = type_member
    Value = type_member

    sig { returns(T::Boolean) }
    def success?; end

    sig { returns(Value) }
    def value; end

    sig { returns(Value) }
    def value!; end

    sig { returns(T::Boolean) }
    def failure?; end

    sig { returns(Error) }
    def cause; end

    sig { params(block: T.proc.params(arg0: Value).returns(T.untyped)).returns(Result[Error, T.untyped]) }
    def map(&block); end

    sig { params(on_failure: T.proc.params(arg0: Error).returns(T.untyped),
                 on_success: T.proc.params(arg0: Value).returns(T.untyped)).returns(T.untyped) }
    def fold(on_failure:, on_success:); end

    sig { params(block: T.proc.params(arg0: Error).returns(Error)).returns(Result[Error, Value]) }
    def map_error(&block); end

    sig { params(block: T.proc.params(arg0: Error).returns(T.untyped)).returns(Result[Error, Value]) }
    def tap_error(&block); end

    sig { params(block: T.proc.params(arg0: Value).returns(Result[Error, T.untyped])).returns(Result[Error, T.untyped]) }
    def flat_map(&block); end

    sig { params(value: Value).returns(Result[Error, Value]) }
    def self.success(value); end

    sig { params(cause: Error).returns(Result[Error, Value]) }
    def self.failure(cause); end

    sig { params(block: T.proc.returns(Value)).returns(Result[Cause, Value]) }
    def self.wrap(&block); end
  end

  class DependencySet
    extend T::Sig

    sig { returns(T::Array[DependencyKey[T.untyped]]) }
    def to_a; end
  end

  class Context
    extend T::Sig

    sig { params(entries: T::Hash[DependencyKey[T.untyped], T.untyped]).void }
    def initialize(entries); end

    sig { returns(Context) }
    def self.empty; end

    sig { params(entries: T::Hash[T.any(Symbol, String, DependencyKey[T.untyped]), T.untyped]).returns(Context) }
    def self.from_hash(entries); end

    sig { returns(Context) }
    def self.current; end

    sig { params(context: Context, blk: T.proc.void).returns(T.untyped) }
    def self.use(context, &blk); end

    sig do
      params(
        key: DependencyKey[T.untyped],
        block: T.nilable(T.proc.params(arg0: DependencyKey[T.untyped]).returns(T.untyped))
      ).returns(T.untyped)
    end
    def fetch(key, &block); end

    sig { params(other: T.any(Context, T::Hash[T.any(DependencyKey[T.untyped], Symbol, String), T.untyped])).returns(Context) }
    def merge(other); end
  end

  class Effect
    extend T::Generic
    extend T::Sig

    Error = type_member
    Value = type_member

    sig { params(description: T.nilable(String)).returns(T.nilable(String)) }
    attr_reader :description

    sig { returns(T::Array[DependencyKey[T.untyped]]) }
    attr_reader :requirements

    sig do
      params(
        description: T.nilable(String),
        requirements: T::Array[DependencyKey[T.untyped]],
        program: T.proc.params(arg0: Context).returns(T.any(Result[Error, Value], Cause, Value))
      ).void
    end
    def initialize(description: nil, requirements: [], &program); end

    sig { params(value: Value, description: T.nilable(String)).returns(Effect[Error, Value]) }
    def self.succeed(value, description: nil); end

    sig { params(cause: Cause, description: T.nilable(String)).returns(Effect[Cause, Value]) }
    def self.fail(cause, description: nil); end

    sig { params(description: T.nilable(String), block: T.proc.returns(Value)).returns(Effect[Cause, Value]) }
    def self.attempt(description: nil, &block); end

    sig { params(proc: Proc, description: T.nilable(String)).returns(Effect[Cause, Value]) }
    def self.from_proc(proc, description: nil); end

    sig { params(context: T.nilable(Context)).returns(Result[Error, Value]) }
    def run(context = nil); end

    sig { params(block: T.proc.params(arg0: Value).returns(T.untyped)).returns(Effect[Error, T.untyped]) }
    def map(&block); end

    sig { params(block: T.proc.params(arg0: Value).returns(Effect[Error, T.untyped])).returns(Effect[Error, T.untyped]) }
    def flat_map(&block); end

    sig { params(overrides: T::Hash[DependencyKey[T.untyped], T.untyped]).returns(Effect[Error, Value]) }
    def provide(overrides); end
  end

  class Layer
    extend T::Sig

    sig do
      params(
        description: T.nilable(String),
        builder: T.proc.params(arg0: Context).returns(T.any(Context, Result[Cause, Context], T::Hash[DependencyKey[T.untyped], T.untyped]))
      ).void
    end
    def initialize(description: nil, &builder); end

    sig { params(context: Context).returns(Result[Cause, Context]) }
    def build(context); end

    sig { returns(Layer) }
    def self.identity; end

    sig { params(hash: T::Hash[DependencyKey[T.untyped], T.untyped], description: T.nilable(String)).returns(Layer) }
    def self.from_hash(hash, description: nil); end
  end

  module Runtime
    extend T::Sig

    sig do
      params(
        effect: Effect[T.untyped, T.untyped],
        layers: T::Array[Layer],
        context: T.nilable(Context),
        raise_on_error: T::Boolean
      ).returns(Result[T.untyped, T.untyped])
    end
    def self.run(effect, layers: [], context: nil, raise_on_error: false); end

    sig { params(effect: Effect[T.untyped, T.untyped], layers: T::Array[Layer], context: T.nilable(Context)).returns(T.untyped) }
    def self.run!(effect, layers: [], context: nil); end

    sig { params(effect: Effect[T.untyped, T.untyped], hash: T::Hash[DependencyKey[T.untyped], T.untyped]).returns(Result[T.untyped, T.untyped]) }
    def self.provide_context(effect, hash); end
  end

  module Interop
    extend T::Sig

    sig do
      params(
        effect: Effect[T.untyped, T.untyped],
        context: T.nilable(Context),
        layers: T::Array[Layer],
        raise_on_error: T::Boolean
      ).returns(Result[T.untyped, T.untyped])
    end
    def self.run(effect, context: nil, layers: [], raise_on_error: false); end

    sig { params(effect: Effect[T.untyped, T.untyped], context: T.nilable(Context), layers: T::Array[Layer]).returns(T.untyped) }
    def self.run!(effect, context: nil, layers: []); end

    sig { params(description: T.nilable(String), block: T.proc.returns(T.untyped)).returns(Effect[Cause, T.untyped]) }
    def self.effectify(description: nil, &block); end

    sig { params(callable: Proc, description: T.nilable(String)).returns(Effect[Cause, T.untyped]) }
    def self.from_callable(callable, description: nil); end

    sig { params(overrides: T::Hash[DependencyKey[T.untyped], T.untyped], block: T.proc.void).returns(T.untyped) }
    def self.with_context(overrides, &block); end

    sig { params(result: Result[T.untyped, T.untyped]).returns(T.untyped) }
    def self.unsafe!(result); end
  end
end
