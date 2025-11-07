# typed: true

module Effect
  # Marker class to represent unsatisfied dependencies in the type system
  class UnsatisfiedDependencies; end

  class Effect
    extend T::Generic
    extend T::Sig

    # Phantom type to track whether dependencies are satisfied
    # T.noreturn = all dependencies satisfied (can run)
    # UnsatisfiedDependencies = has unsatisfied dependencies (cannot run)
    Requirements = type_member

    attr_reader :description, :requirements

    sig { params(value: T.untyped, description: T.nilable(String)).returns(Effect[T.noreturn]) }
    def self.succeed(value, description: nil)
      build(description: description) { |_ctx| Result.success(value) }
    end

    sig { params(cause: Cause, description: T.nilable(String)).returns(Effect[T.noreturn]) }
    def self.fail(cause, description: nil)
      build(description: description) { |_ctx| Result.failure(cause) }
    end

    # Access a service dependency - returns Effect[UnsatisfiedDependencies] that yields the service
    sig do
      params(
        key: T.any(DependencyKey, Symbol, String),
        description: T.nilable(String)
      ).returns(Effect[UnsatisfiedDependencies])
    end
    def self.service(key, description: nil)
      dependency_key = case key
      when DependencyKey
        key
      when Symbol, String
        DependencyKey.new(key)
      else
        # Sig guarantees key is DependencyKey | Symbol | String
        T.absurd(key)
      end

      T.unsafe(
        new(
          description: description || "service(#{dependency_key.name})",
          requirements: [dependency_key]
        ) do |ctx|
          Result.success(ctx.fetch(dependency_key))
        end
      )
    end

    sig { params(description: T.nilable(String), block: T.proc.returns(T.untyped)).returns(Effect[T.noreturn]) }
    def self.attempt(description: nil, &block)
      build(description: description) { |_ctx| Result.wrap(&block) }
    end

    sig { params(proc: T.untyped, description: T.nilable(String)).returns(Effect[T.noreturn]) }
    def self.from_proc(proc, description: nil)
      raise ArgumentError, "proc must respond to #call" unless proc.respond_to?(:call)

      build(description: description) { |_ctx| Result.wrap { proc.call } }
    end

    sig { params(description: T.nilable(String), block: T.proc.params(ctx: Context).returns(T.untyped)).returns(Effect[T.noreturn]) }
    def self.from_block(description: nil, &block)
      build(description: description, &block)
    end

    # Constructor - use factory methods (Effect.build, Effect.service) instead of calling directly
    sig { params(description: T.nilable(String), requirements: T::Array[DependencyKey], program: T.proc.params(ctx: Context).returns(T.untyped)).void }
    def initialize(description: nil, requirements: [], &program)
      @description = description
      @requirements = requirements.freeze
      @program = program
    end

    # Factory method for effects WITHOUT dependencies - returns Effect[T.noreturn]
    sig do
      params(
        description: T.nilable(String),
        block: T.proc.params(ctx: Context).returns(T.untyped)
      ).returns(Effect[T.noreturn])
    end
    def self.build(description: nil, &block)
      T.unsafe(new(description: description, requirements: [], &block))
    end

    def run(context = nil)
      ctx = context || Context.current
      normalize_result(@program.call(ctx))
    rescue FailureError => e
      Result.failure(e.cause)
    rescue StandardError => exception
      Result.failure(
        Cause.exception(
          exception,
          tag: :unhandled_exception,
          message: "Unhandled exception in effect#{description ? " (#{description})" : ""}"
        )
      )
    end

    def map(&block)
      base = self
      T.unsafe(
        Effect.new(description: chain_description("map"), requirements: requirements) do |ctx|
          base.run(ctx).map(&block)
        end
      )
    end

    def flat_map(&block)
      base = self
      T.unsafe(
        Effect.new(description: chain_description("flat_map"), requirements: requirements) do |ctx|
          first = base.run(ctx)
          next first if first.failure?

          begin
            next_effect = block.call(first.value)
          rescue FailureError => e
            next Result.failure(e.cause)
          rescue StandardError => exception
            next Result.failure(Cause.exception(exception, tag: :flat_map))
          end

          unless next_effect.is_a?(Effect)
            next Result.failure(
              Cause.new(tag: :invalid_flat_map, message: "Expected Effect, got #{next_effect.inspect}")
            )
          end

          next_effect.run(ctx)
        end
      )
    end

    def map_error(&block)
      base = self
      T.unsafe(
        Effect.new(description: chain_description("map_error"), requirements: requirements) do |ctx|
          base.run(ctx).map_error(&block)
        end
      )
    end

    def tap_error(&block)
      base = self
      T.unsafe(
        Effect.new(description: chain_description("tap_error"), requirements: requirements) do |ctx|
          result = base.run(ctx)
          if result.failure?
            begin
              block.call(result.cause)
            rescue StandardError => exception
              next Result.failure(Cause.exception(exception, tag: :tap_error))
            end
          end
          result
        end
      )
    end

    # Provide dependencies - transforms Effect[UnsatisfiedDependencies] → Effect[T.noreturn]
    sig { params(overrides: T::Hash[DependencyKey, T.untyped]).returns(Effect[T.noreturn]) }
    def provide(overrides)
      base = self
      # After providing dependencies, requirements are satisfied (empty array)
      T.unsafe(
        Effect.new(description: chain_description("provide"), requirements: []) do |ctx|
          provided = ctx.merge(overrides)
          Context.use(provided) { base.run(provided) }
        end
      )
    end

    # Provide dependencies via Layer - transforms Effect[UnsatisfiedDependencies] → Effect[T.noreturn]
    sig { params(layer: Layer).returns(Effect[T.noreturn]) }
    def provide_layer(layer)
      base = self
      # After providing layer, requirements are satisfied (empty array)
      T.unsafe(
        Effect.new(description: chain_description("provide_layer"), requirements: []) do |ctx|
          layer.build(ctx).flat_map do |layer_ctx|
            merged = ctx.merge(layer_ctx)
            Context.use(merged) { base.run(merged) }
          end
        end
      )
    end

    def catch_all(&block)
      base = self
      T.unsafe(
        Effect.new(description: chain_description("catch_all"), requirements: requirements) do |ctx|
          result = base.run(ctx)
          next result if result.success?

          begin
            recovery = block.call(result.cause)
          rescue FailureError => e
            next Result.failure(e.cause)
          rescue StandardError => exception
            next Result.failure(Cause.exception(exception, tag: :catch_all))
          end

          unless recovery.is_a?(Effect)
            next Result.failure(
              Cause.new(tag: :invalid_recovery, message: "catch_all block must return an Effect, got #{recovery.inspect}")
            )
          end

          recovery.run(ctx)
        end
      )
    end

    def with_description(extra)
      T.unsafe(
        Effect.new(description: chain_description(extra), requirements: requirements, &@program)
      )
    end

    private

    def normalize_result(value)
      case value
      when Result
        value
      when Cause
        Result.failure(value)
      else
        Result.success(value)
      end
    end

    def chain_description(suffix)
      [description, suffix].compact.join(" -> ")
    end
  end
end
