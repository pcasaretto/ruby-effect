# frozen_string_literal: true

require "test_helper"

class StreamTest < Minitest::Test
  def test_stream_chunk_and_to_task
    stream = Effect::Stream.from_array([1, 2, 3, 4])
      .map { |n| n * 2 }
      .chunk(3)

    task = stream.to_task
    result = with_runtime { |runtime| runtime.run(task) }

    assert_equal [[2, 4, 6], [8]], result
  end

  def test_merge_consumes_each_stream
    a = Effect::Stream.from_array([1, 3])
    b = Effect::Stream.from_array([2, 4])
    merged = Effect::Stream.merge(a, b)

    assert_equal [1, 2, 3, 4], merged.enumerator.take(4)
  end
end
