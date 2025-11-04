# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "minitest/autorun"
require "effect"

module TestHelpers
  def with_runtime(context: Effect::Context.empty, scheduler: nil, &block)
    runtime = Effect::Runtime.new(context: context, scheduler: scheduler)
    block.call(runtime)
  end
end

Minitest::Test.include(TestHelpers)
