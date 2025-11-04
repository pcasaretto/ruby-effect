# frozen_string_literal: true

require "test_helper"
require "stringio"

class LayerTest < Minitest::Test
  def test_layer_provides_value
    layer = Effect::Layer.from_value(:answer, 42)
    task = Effect::Task.access(:answer).provide_layer(layer)

    value = with_runtime { |runtime| runtime.run(task) }
    assert_equal 42, value
  end

  def test_layers_compose_and_finalize
    finalizers = []
    resource_layer = Effect::Layer.from_resource(:resource) do
      resource = Object.new
      finalizer = -> { finalizers << :cleaned }
      [resource, finalizer]
    end

    logger_io = StringIO.new
    logging_layer = Effect::Layers::Logging.layer(io: logger_io)

    composed = Effect::Layer.stack(logging_layer, resource_layer)

    task = Effect::Task.access(:resource)
      .and_then do |resource|
        Effect::Layers::Logging.info { "resource=#{resource.object_id}" }.map { resource }
      end
      .provide_layer(composed)
    with_runtime { |runtime| runtime.run(task) }

    assert_equal [:cleaned], finalizers
    assert_match(/INFO/, logger_io.string)
  end
end
