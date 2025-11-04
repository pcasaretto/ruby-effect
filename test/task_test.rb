# frozen_string_literal: true

require "test_helper"

class TaskTest < Minitest::Test
  def test_succeed_map
    task = Effect::Task.succeed(1).map { |value| value + 1 }

    result = with_runtime { |runtime| runtime.run(task) }
    assert_equal 2, result
  end

  def test_failure_cause_propagates
    error = :boom
    task = Effect::Task.fail(error)

    result = with_runtime { |runtime| runtime.run_result(task) }
    assert result.failure?
    assert_equal error, result.cause.error
  end

  def test_retry_exhausts_schedule
    attempts = 0
    failing = Effect::Task.new do |scope|
      attempts += 1
      scope.failure(Effect::Cause.fail(:boom))
    end

    schedule = Effect::Schedule.fixed(0, limit: 2)
    retried = failing.retry(schedule, retry_on: [:boom])

    result = with_runtime { |runtime| runtime.run_result(retried) }

    assert result.failure?
    assert_equal 3, attempts
  end

  def test_provide_all_overrides_context
    task = Effect::Task.access(:value).provide_all(value: 42)

    result = with_runtime { |runtime| runtime.run(task) }
    assert_equal 42, result
  end
end
