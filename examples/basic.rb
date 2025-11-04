# typed: true
# frozen_string_literal: true

require_relative "../lib/effect"
require "logger"

LOGGER_TAG = Effect::Typed.tag(:logger, Logger)
STORE_TAG = Effect::Typed.tag(:persistence_store, Effect::Layers::Persistence::MemoryStore)

logging_layer = Effect::Layers::Logging.console(level: Logger::INFO)
store_layer = Effect::Layers::Persistence.memory(seed: {
  users: [
    { id: 1, name: "Ada" },
    { id: 2, name: "Alan" }
  ]
})

program = Effect::Typed.service(STORE_TAG)
  .map do |store|
    store.find(:users) { |row| row[:id] == 1 } || raise(KeyError, "missing user 1")
  end

program = Effect::Typed.provide(program, STORE_TAG, store_layer)

program = program.and_then do |user|
  Effect::Typed.service(LOGGER_TAG)
    .tap { |logger| logger.info("loaded #{user[:name]}") }
    .map { user }
end

program = Effect::Typed.provide(program, LOGGER_TAG, logging_layer)

puts Effect::Typed.run(program)
