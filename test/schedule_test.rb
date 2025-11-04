# frozen_string_literal: true

require "test_helper"

class ScheduleTest < Minitest::Test
  def test_fixed_schedule_respects_limit
    schedule = Effect::Schedule.fixed(0.5, limit: 3)
    assert_equal [0.5, 0.5, 0.5], schedule.take(3)
  end

  def test_exponential_schedule_caps_at_max
    schedule = Effect::Schedule.exponential(base: 0.1, factor: 2.0, max: 0.3, limit: 4)
    assert_equal [0.1, 0.2, 0.3, 0.3], schedule.take(4)
  end
end
