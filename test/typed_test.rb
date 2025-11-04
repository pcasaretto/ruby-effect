# typed: true
# frozen_string_literal: true

require "test_helper"
require "logger"

class TypedTest < Minitest::Test
  LOGGER_TAG = Effect::Typed.tag(:logger, Logger)

  def test_service_success_when_dependency_present
    task = Effect::Typed.service(LOGGER_TAG)
    satisfied = Effect::Typed.provide(task, LOGGER_TAG, Effect::Layers::Logging.console(level: Logger::INFO))

    effect = Effect::Typed.to_effect(satisfied)
    result = with_runtime { |runtime| runtime.run_result(effect) }
    assert result.success?
    assert_instance_of Logger, result.value
  end

  def test_service_failure_when_dependency_missing
    task = Effect::Typed.service(LOGGER_TAG)
    result = with_runtime { |runtime| runtime.run_result(Effect::Typed.to_effect(task)) }

    assert result.failure?
    assert_kind_of KeyError, result.cause.error
  end

  def test_service_failure_when_wrong_type
    layer = Effect::Layer.from_value(:logger, Object.new)

    task = Effect::Typed.service(LOGGER_TAG)
    satisfied = Effect::Typed.provide(task, LOGGER_TAG, layer)
    result = with_runtime { |runtime| runtime.run_result(Effect::Typed.to_effect(satisfied)) }

    assert result.failure?
    assert_kind_of TypeError, result.cause.error
  end
end
