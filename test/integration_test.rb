# frozen_string_literal: true

require "test_helper"
require "logger"
require "stringio"

class IntegrationTest < Minitest::Test
  def test_basic_layered_program
    store_layer = Effect::Layers::Persistence.memory(seed: {
      users: [
        { id: 1, name: "Ada" },
        { id: 2, name: "Alan" }
      ]
    })

    log_io = StringIO.new
    log_layer = Effect::Layers::Logging.layer(io: log_io, level: Logger::INFO)

    program = Effect::Task.access(:persistence_store)
      .and_then do |store|
        Effect::Task.from { store.find(:users) { |row| row[:id] == 2 } }
      end
      .and_then do |user|
        Effect::Layers::Logging.info { "loaded=#{user[:name]}" }.map { user }
      end
      .provide_layer(Effect::Layer.stack(log_layer, store_layer))

    user = with_runtime { |runtime| runtime.run(program) }
    assert_equal({ id: 2, name: "Alan" }, user)
    assert_match(/loaded=Alan/, log_io.string)
  end
end
