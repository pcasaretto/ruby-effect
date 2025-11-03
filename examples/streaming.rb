# frozen_string_literal: true

require_relative "../lib/effect"

include Effect::Prelude

numbers = Stream.from_array((1..5).to_a)
  .map { |n| n * 2 }
  .chunk(2)
  .to_task

puts Effect::Runtime.default.run(numbers)
