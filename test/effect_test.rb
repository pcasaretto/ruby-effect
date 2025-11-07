# typed: false

require_relative "test_helper"

class EffectTest < Minitest::Test
  LOGGER = Effect::DependencyKey.new(:logger)
  TELEMETRY = Effect::DependencyKey.new(:telemetry)

  def test_basic_success
    effect = Effect::Effect.succeed(42)
    result = Effect::Runtime.run(effect)

    assert result.success?
    assert_equal 42, result.value
  end

  def test_exception_is_wrapped
    effect = Effect::Effect.attempt { raise "boom" }
    result = Effect::Runtime.run(effect)

    assert result.failure?
    assert_equal :exception, result.cause.tag
    assert_match(/boom/, result.cause.message)
  end

  def test_dependency_resolution
    layer = Effect::Layer.from_hash({ LOGGER => ->(message) { message } })
    effect = Effect::Effect.new(requirements: [LOGGER]) do |ctx|
      logger = ctx.fetch(LOGGER)
      Effect::Result.wrap { logger.call("hello") }
    end

    result = Effect::Runtime.run(effect, layers: [layer])

    assert result.success?
    assert_equal "hello", result.value
  end

  def test_catch_all
    failing = Effect::Effect.fail(
      Effect::Cause.new(tag: :boom, message: "bad")
    )

    recovered = failing.catch_all do |cause|
      Effect::Effect.succeed("handled #{cause.tag}")
    end

    result = Effect::Runtime.run(recovered)
    assert result.success?
    assert_equal "handled boom", result.value
  end
end
