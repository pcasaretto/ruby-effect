# Effect.rb (prototype)

This repository sketches a Ruby-flavoured port of [Effect](https://effect.website/). It keeps
Effect's algebra of typed effects, structured concurrency, layers, and fiber-friendly
ergonomics while leaning on Ruby idioms: blocks, dynamic typing, and Sorbet/RBS support.

## Getting started

```ruby
require "effect"
include Effect::Prelude

UserRepo = Layer.stack(
  console_logger,
  memory_store(seed: { users: [{ id: 1, name: "Ada" }] })
)

find_user = Task.access(:persistence_store).and_then do |store|
  Task.from do
    store.find(:users) { |row| row[:id] == 1 } || raise(KeyError, "missing user")
  end
end

program =
  find_user
    .tap { |user| Logging.info { "loaded #{user[:name]}" } }
    .provide_layer(UserRepo)

Runtime.default.run(program)
```

- `Task` describes effectful computations with `map`, `and_then`, `rescue`, `retry`, and
  `fork` for fibers.
- `Layer` composes environment provisioning with resource-safe finalizers.
- `Schedule` drives retry/backoff logic.
- `Stream` wraps lazy enumerators for pipelines and batching.

## Runtime

`Effect::Runtime` wraps a scheduler (inline threads by default, `async` gem when available).
It supervises forked tasks, keeps contexts fiber-local, and exposes `run`/`run_result`.

```ruby
program = Task.from { :hello }.
  fork.and_then { |handle| handle.join }.
  map(&:value!)

Runtime.default.run(program)
# => :hello
```

## Layers and context

Layers translate dependencies into context values. They compose left-to-right and clean up
resources in reverse order.

```ruby
FetchUser = Layer.from_resource(:db) do
  client = DB::Client.new(ENV.fetch("DATABASE_URL"))
  [client, -> { client.close }]
end

program = Task.access(:db).
  and_then { |db| Task.from { db.get(42) } }.
  provide_layer(FetchUser)
```

Prebuilt layers live under `Effect::Layers`:

- `Layers::Logging.console` – structured logging via `Logger`.
- `Layers::HTTP.client` – wrap `Net::HTTP` with a base URI.
- `Layers::Persistence.memory` – simple in-memory repository (handy for tests).

## Scheduling & retries

`Effect::Schedule` builders (`fixed`, `exponential`, `fibonacci`) feed `Task#retry`.

```ruby
fetch = Layers::HTTP.get("/users/42").
  retry(Schedule.exponential(base: 0.1, max: 2.0, limit: 5), retry_on: [Timeout::Error])
```

## Streams

Streams orchestrate lazy, potentially infinite data. They are built atop `Enumerator` and
compose with `map`, `filter`, `chunk`, `merge`, and `zip`.

```ruby
Stream.from_array([1, 2, 3])
  .map { |n| n * 2 }
  .chunk(2)
  .to_task
  .run
# => [[2, 4], [6]]
```

## Types with RBS

`sig/effect.rbs` provides Sorbet/RBS signatures that approximate the effect typing model.
Pair it with `steep` or `sorbet` to track capability usage in larger applications.

## Examples

See the `examples/` directory for runnable snippets:

- `basic.rb` – layering + persistence + logging.
- `http_retry.rb` – HTTP client with retry schedule.
- `streaming.rb` – using streams for batching and fan-in.

## Why Rubyists Might Care

Effect-style programming answers a handful of pain points that show up in larger Ruby systems:

- **Explicit dependency wiring.** Layers let you describe dependencies declaratively and pass them through the call graph without parameter soup or global state. Instead of sprinkling `Thread.current[:foo]` or memoized singletons, you compose `Layer`s alongside the code that needs them.
- **Structured async without callback gymnastics.** Tasks compose like plain data while still running on fibers/threads under the hood. That gives you `fork`, `retry`, and supervision trees without juggling raw `Fiber` objects or building bespoke lifecycle code.
- **Predictable error handling.** Every effect either succeeds with a value or fails with a structured `Cause`. Recoveries live next to the call sites via `Task#rescue`, making fallbacks discoverable and testable—no hidden `rescue nil` or swallowed stack traces.
- **Deterministic resource lifecycles.** Layers model acquisition/release as part of the effect description. Finalizers always run in reverse order, which removes the “did we close that connection?” class of bugs.
- **Testable effects.** Because a Task is just data until you `run` it, swapping a layer (say an in-memory persistence stub) or inspecting the result is trivial. No need for monkeypatching or setting up global doubles.
- **Typed affordances when you want them.** RBS/Sorbet signatures track which capabilities are in scope so you can catch “missing dependency” issues at static-check time without giving up Ruby’s flexibility.

## Caveats

This is a prototype. Concurrency semantics are conservative, finalizer errors surface as
defects, and extensive effect combinators (race, structured scheduling) remain to be built.
The goal is to spark exploration, not provide a production-ready runtime.
