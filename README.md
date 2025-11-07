# Effect for Ruby (work-in-progress)

An experiment in bringing the ergonomics of [Effect-TS](https://effect.website/) to Ruby while staying friendly to the existing ecosystem. The goal is to make dependencies explicit, model errors as values, and catch missing dependencies at compile time with Sorbet.

## Core Ideas

- **Effect values instead of immediate execution** – an `Effect::Effect` describes work that, when run, produces either a successful `Result` or a `Cause`.
- **Compile-time dependency tracking** – Sorbet enforces that effects with unsatisfied dependencies cannot be run. `Effect[T.noreturn]` means ready to run, `Effect[UnsatisfiedDependencies]` means missing dependencies.
- **Pipeline-style service access** – use `Effect.service(KEY)` to access dependencies, compose with `flat_map` for clean, type-safe code.
- **Errors as data** – `Effect::Cause` captures structured failure information (tag, message, metadata, wrapped exception) so callers must observe unhappy paths.
- **Composable wiring with `Layer`** – layers provide dependency implementations; tests can swap layers to isolate effects.
- **Interop-first** – helper APIs let you wrap existing Ruby methods in effects or run effects imperatively so adoption can be incremental.

## Quick Start

```ruby
require_relative "lib/effect"

HttpGet = Effect::Effect.attempt(description: "http.get") do
  # your IO here, just a dummy example
  response = Net::HTTP.get(URI("https://example.com")) # raises? it's wrapped
  response.force_encoding("UTF-8")
end

result = Effect::Runtime.run(HttpGet)

result.fold(
  on_failure: ->(cause) { warn "http failed: #{cause.to_h.inspect}" },
  on_success: ->(body) { puts body }
)
```

## Making Dependencies Explicit

Use `Effect.service(KEY)` to access dependencies in a pipeline style:

```ruby
TELEMETRY = Effect::DependencyKey.new(:telemetry)
LOGGER = Effect::DependencyKey.new(:logger)

Catalog = Effect::Effect.service(TELEMETRY).flat_map do |telemetry|
  telemetry.call("catalog.fetch.started")

  Effect::Effect.attempt do
    product = { id: 42, name: "Widget" }
    telemetry.call("catalog.fetch.finished", product)
    product
  end
end

logger_layer = Effect::Layer.from_hash({
  LOGGER => ->(message, metadata = {}) { puts("#{message} #{metadata.inspect}") }
})

telemetry_layer = Effect::Layer.new(description: "telemetry") do |ctx|
  logger = ctx.fetch(LOGGER)
  {
    TELEMETRY => ->(event, metadata = {}) { logger.call("[telemetry] #{event}", metadata) }
  }
end

product = Effect::Runtime.run(Catalog, layers: [logger_layer, telemetry_layer]).value!
```

Tests remain easy by swapping layers:

```ruby
fake_calls = []

fake_layer = Effect::Layer.from_hash({
  TELEMETRY => ->(event, metadata = {}) { fake_calls << [event, metadata] }
})

Effect::Runtime.run(Catalog, layers: [fake_layer])

assert_equal [["catalog.fetch.started", {}], ["catalog.fetch.finished", { id: 42, name: "Widget" }]], fake_calls
```

## Error Handling

Uncaught exceptions are converted into `Cause` values automatically:

```ruby
danger = Effect::Effect.attempt { raise "boom" }
result = Effect::Runtime.run(danger)

if result.failure?
  puts result.cause.tag        # => :exception
  puts result.cause.message    # => "boom"
  puts result.cause.metadata   # => { original_exception_class: "RuntimeError" }
end
```

Define domain failures explicitly for clarity:

```ruby
NotFound = Effect::Cause.new(tag: :not_found, message: "Order missing")
find_order = Effect::Effect.fail(NotFound)
```

Recover with `catch_all` (or `map_error` if you just want to tweak the cause):

```ruby
safe_find = find_order.catch_all do |cause|
  Effect::Effect.succeed({ default: true, reason: cause.tag })
end
```

## Interop Helpers

- `Effect::Interop.effectify { ... }` – turn a plain Ruby block into an effect (exceptions captured as causes).
- `Effect::Interop.run(effect)` – execute an effect from imperative code and leave the caller to decide how to handle the `Result`.
- `Effect::Interop.run(effect).value!` – opt into raising on failure explicitly (useful at top-level boundaries).
- `Effect::Interop.with_context(logger: fake_logger) { ... }` – temporarily enrich the thread-local context when mixing effectful and legacy code paths.

These escape hatches let you introduce effects at the edges (HTTP calls, background jobs) and wire them back into the rest of the application without large refactors.

## Examples

- `examples/explicit_dependencies.rb` – show how effects surface dependencies so tests can supply fakes.
- `examples/pipeline_style.rb` – demonstrate clean composition with `Effect.service()` and `flat_map`.
- `examples/failing_missing_dependency.rb` – see how Sorbet catches missing dependencies at compile time.
- `examples/telemetry_extension.rb` – add telemetry around an existing effect without touching its body.
- `examples/error_handling.rb` – demonstrate turning exceptions into causes and recovering explicitly.
- `examples/interop.rb` – integrate effects with legacy Ruby controllers and renderers.
- `examples/catalog.rb` – end-to-end sample combining logging, telemetry, and domain logic.

Run any script directly, e.g.:

```bash
ruby examples/catalog.rb
ruby examples/pipeline_style.rb
```

## Tests

```bash
ruby -Itest test/effect_test.rb
```

## Static Check

[Sorbet](https://sorbet.org) catches missing dependencies at compile time using phantom types. Run:

```bash
bundle install
bin/effect_check   # wraps `bundle exec srb tc`
```

Sorbet enforces that:

- **Effects with unsatisfied dependencies cannot be run** – `Effect.service(KEY)` returns `Effect[UnsatisfiedDependencies]`, which `Runtime.run` rejects. You must call `provide_layer` to transform it to `Effect[T.noreturn]` before running.
- **Dependencies are type-safe** – dependency keys are typed `Effect::DependencyKey` constants, preventing raw symbol usage.
- **Errors must be handled** – `Runtime.run` returns `Effect::Result`, forcing you to `fold`, `value!`, or otherwise acknowledge the failure channel.

Wire it into CI to block merges that ignore errors or skip wiring a dependency.

### See the Failure

`examples/failing_missing_dependency.rb` intentionally tries to run an effect with unsatisfied dependencies:

```ruby
# ❌ BROKEN: This fails type checking
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
```

Running `bundle exec srb tc` highlights the type error, showing the guardrails in action.

## Next Steps

- Flesh out a richer algebra (parallelism, retries, scheduling) on top of the current primitives.
- Explore integration with Rack/Rails through middleware that populates the runtime context automatically.
- Design Sorbet/RBS signatures so typed projects can get coverage on context keys and effect shapes.
- Add structured logging/tracing layers to show stronger telemetry benefits.
