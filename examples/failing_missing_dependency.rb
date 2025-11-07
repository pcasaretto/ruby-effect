# typed: true

require_relative "../lib/effect"

module Examples
  module FailingMissingDependency
    extend T::Sig

    LOGGER_SIG = T.type_alias do
      T.proc.params(message: String, metadata: T::Hash[Symbol, T.untyped]).void
    end

    LOGGER = Effect::Keys.define(
      :logger,
      type: LOGGER_SIG
    )

    sig { returns(Effect::Effect[Effect::UnsatisfiedDependencies]) }
    def self.effect_with_unsatisfied_deps
      # This effect has UNSATISFIED requirements (LOGGER not provided)
      # Effect.service returns Effect[UnsatisfiedDependencies] automatically
      Effect::Effect.service(LOGGER).flat_map do |logger|
        logger.call("Computing answer", {})
        Effect::Effect.succeed(42)
      end
    end

    # ❌ BROKEN: This fails type checking - effect has unsatisfied dependencies!
    sig { returns(Effect::Result) }
    def self.run_without_logger_layer
      # ERROR: Expected Effect[T.noreturn], got Effect[UnsatisfiedDependencies]
      Effect::Runtime.run(effect_with_unsatisfied_deps, layers: [])
    end

    # ✅ FIXED: Provide the LOGGER dependency using provide_layer
    sig { returns(Integer) }
    def self.run_with_logger_layer
      logger_layer = Effect::Layer.from_hash({
        LOGGER => ->(message, metadata) { puts "[LOG] #{message}" }
      })

      # provide_layer satisfies dependencies: Effect[UnsatisfiedDependencies] → Effect[T.noreturn]
      effect_with_logger = effect_with_unsatisfied_deps.provide_layer(logger_layer)

      # Now Runtime.run accepts it!
      result = Effect::Runtime.run(effect_with_logger, layers: [])
      result.value!
    end
  end
end

if $PROGRAM_NAME == __FILE__
  puts "Running effect with satisfied dependencies:"
  answer = Examples::FailingMissingDependency.run_with_logger_layer
  puts "Answer: #{answer}"
end
