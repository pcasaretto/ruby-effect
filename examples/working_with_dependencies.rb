# typed: true

require_relative "../lib/effect"

module Examples
  module WorkingWithDependencies
    extend T::Sig

    LOGGER_SIG = T.type_alias do
      T.proc.params(message: String, metadata: T::Hash[Symbol, T.untyped]).void
    end

    LOGGER = Effect::Keys.define(
      :logger,
      type: LOGGER_SIG
    )

    def self.effect
      # Effect with UNSATISFIED dependencies - returns Effect[UnsatisfiedDependencies]
      Effect::Effect.new(requirements: [LOGGER], description: "working.with_dependencies") do |ctx|
        logger = T.let(ctx.fetch(LOGGER), LOGGER_SIG)
        logger.call("Computing result", {})
        Effect::Result.success(42)
      end
    end

    # ❌ This would fail type checking:
    # Effect::Runtime.run(effect, layers: [])

    # ✅ FIX #1: Provide the dependency via a Layer
    def self.fix_with_layer
      logger_layer = Effect::Layer.from_hash({
        LOGGER => ->(message, metadata) { puts "[LOG] #{message} #{metadata.inspect}" }
      })

      # Now Runtime.run works because the layer provides LOGGER
      result = Effect::Runtime.run(effect, layers: [logger_layer])
      result.value!
    end

    # ✅ FIX #2: Build an effect WITHOUT dependencies from the start
    def self.effect_without_deps
      Effect::Effect.build(description: "no_deps") do |ctx|
        # No dependencies needed - this returns Effect[T.noreturn]
        Effect::Result.success(42)
      end
    end

    sig { returns(Integer) }
    def self.run_no_deps
      Effect::Runtime.run(effect_without_deps).value!
    end
  end
end

if $PROGRAM_NAME == __FILE__
  puts "Fix #1: Using layers to satisfy dependencies"
  result1 = Examples::WorkingWithDependencies.fix_with_layer
  puts "Result: #{result1}"

  puts "\nFix #2: Building effects without dependencies"
  result2 = Examples::WorkingWithDependencies.run_no_deps
  puts "Result: #{result2}"
end
