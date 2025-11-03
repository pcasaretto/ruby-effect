# frozen_string_literal: true

require_relative "../lib/effect"
require "logger"

include Effect::Prelude

UserLayer = Layer.stack(
  Logging.console(level: Logger::INFO),
  Persistence.memory(seed: {
    users: [
      { id: 1, name: "Ada" },
      { id: 2, name: "Alan" }
    ]
  })
)

find_user = ->(id) do
  Task.access(:persistence_store).and_then do |store|
    Task.from do
      store.find(:users) { |row| row[:id] == id } || raise(KeyError, "missing user #{id}")
    end
  end
end

program =
  find_user.call(1)
  .and_then do |user|
    Logging.info { "loaded #{user[:name]}" }.map { user }
  end
  .provide_layer(UserLayer)

puts Effect::Runtime.default.run(program)
