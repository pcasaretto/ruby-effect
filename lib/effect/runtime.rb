# typed: true

module Effect
  module Runtime
    extend T::Sig
    module_function

    sig do
      params(
        effect: ::Effect::Effect[T.noreturn],
        layers: T::Array[::Effect::Layer],
        context: T.nilable(::Effect::Context),
        raise_on_error: T::Boolean
      ).returns(::Effect::Result)
    end
    def run(effect, layers: [], context: Context.current, raise_on_error: false)
      unless effect.respond_to?(:run)
        return Result.failure(
          Cause.new(tag: :invalid_effect, message: "Runtime.run expected an Effect, got #{effect.inspect}")
        )
      end

      resolve_layers(Kernel.Array(layers), context).flat_map do |layered_context|
        Context.use(layered_context) do
          result = effect.run(layered_context)
          if raise_on_error && result.failure?
            Kernel.raise FailureError.new(result.cause)
          end
          result
        end
      end
    end

    sig do
      params(
        effect: ::Effect::Effect[T.noreturn],
        layers: T::Array[::Effect::Layer],
        context: T.nilable(::Effect::Context)
      ).returns(T.untyped)
    end
    def run!(effect, layers: [], context: Context.current)
      run(effect, layers: layers, context: context, raise_on_error: true).value!
    end

    sig do
      params(
        effect: ::Effect::Effect[T.noreturn],
        hash: T::Hash[::Effect::DependencyKey, T.untyped]
      ).returns(::Effect::Result)
    end
    def provide_context(effect, hash)
      run(effect.provide(hash))
    end

    sig do
      params(
        layers: T::Array[::Effect::Layer],
        context: ::Effect::Context
      ).returns(::Effect::Result)
    end
    def resolve_layers(layers, context)
      layers.reduce(Result.success(context)) do |acc, layer|
        acc.flat_map do |current_ctx|
          layer.build(current_ctx).map do |provided_ctx|
            current_ctx.merge(provided_ctx)
          end
        end
      end
    end
    private_class_method :resolve_layers
  end
end
