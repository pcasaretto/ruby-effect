#!/usr/bin/env ruby
# frozen_string_literal: true
# typed: false

require_relative "../lib/effect"

LOGGER = Effect::DependencyKey.new(:logger)
TELEMETRY = Effect::DependencyKey.new(:telemetry)

module Adapters
  module Logger
    def self.layer(io: $stdout)
      Effect::Layer.new(description: "logger") do |_ctx|
        {
          LOGGER => lambda do |message, metadata = {}|
            io.puts("#{message} #{metadata.empty? ? "" : metadata.inspect}")
          end
        }
      end
    end
  end
end

module Layers
  Telemetry = Effect::Layer.new(description: "telemetry") do |ctx|
    logger = ctx.fetch(LOGGER) { |_missing| ->(message, _meta = {}) { warn("missing logger #{message}") } }
    {
      TELEMETRY => lambda do |event, metadata = {}|
        logger.call("[telemetry] #{event}", metadata)
      end
    }
  end
end

class Catalog
  def self.fetch(id)
    Effect::Effect.new(description: "catalog.fetch", requirements: [TELEMETRY]) do |ctx|
      telemetry = ctx.fetch(TELEMETRY)
      telemetry.call("catalog.fetch.started", id: id)

      Effect::Result.wrap do
        raise ArgumentError, "missing id" unless id

        product = { id: id, name: "Widget", price_cents: 1234 }
        telemetry.call("catalog.fetch.succeeded", id: id)
        product
      end
    end
  end

  def self.fetch!(id, layers: default_layers)
    Effect::Interop.run(fetch(id), layers: layers).value!
  end

  def self.default_layers
    [
      Adapters::Logger.layer(io: $stdout),
      Layers::Telemetry
    ]
  end
end

if $PROGRAM_NAME == __FILE__
  puts "Happy path:"
  Effect::Runtime.run(Catalog.fetch(42), layers: Catalog.default_layers).fold(
    on_failure: ->(cause) { warn "failure: #{cause.to_h.inspect}" },
    on_success: ->(product) { puts "product=#{product.inspect}" }
  )

  puts "\nFailure path:"
  Effect::Runtime.run(Catalog.fetch(nil), layers: Catalog.default_layers).fold(
    on_failure: ->(cause) { warn "failure: #{cause.to_h.inspect}" },
    on_success: ->(product) { puts "product=#{product.inspect}" }
  )
end
