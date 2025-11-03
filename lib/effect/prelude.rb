# frozen_string_literal: true

require "logger"

module Effect
  module Prelude
    Task = Effect::Task
    Layer = Effect::Layer
    Schedule = Effect::Schedule
    Stream = Effect::Stream
    Layers = Effect::Layers
    Logging = Effect::Layers::Logging
    HTTP = Effect::Layers::HTTP
    Persistence = Effect::Layers::Persistence

    module_function

    def succeed(value = nil)
      Task.succeed(value)
    end

    def fail(error)
      Task.fail(error)
    end

    def from(&block)
      Task.from(&block)
    end

    def access(key)
      Task.access(key)
    end

    def console_logger(level: ::Logger::INFO)
      Logging.console(level: level)
    end

    def memory_store(seed: {})
      Persistence.memory(seed: seed)
    end

    def fixed_schedule(interval, limit: nil)
      Schedule.fixed(interval, limit: limit)
    end

    def exponential_schedule(base:, factor: 2.0, max: nil, limit: nil)
      Schedule.exponential(base: base, factor: factor, max: max, limit: limit)
    end

    def runtime
      Runtime.default
    end
  end
end
