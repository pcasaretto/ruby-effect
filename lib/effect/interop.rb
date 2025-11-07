# typed: true

module Effect
  module Interop
    module_function

    def run(effect, context: nil, layers: [], raise_on_error: false)
      Runtime.run(effect, layers: layers, context: context || Context.current, raise_on_error: raise_on_error)
    end

    def run!(effect, context: nil, layers: [])
      Runtime.run(effect, layers: layers, context: context || Context.current, raise_on_error: true).value!
    end

    def effectify(description: nil, &block)
      Effect.attempt(description: description, &block)
    end

    def from_callable(callable, description: nil)
      Effect.from_proc(callable, description: description)
    end

    def with_context(overrides)
      context = Context.current.merge(overrides)
      Context.use(context) { yield }
    end

    def unsafe!(result)
      result.value!
    end
  end
end
