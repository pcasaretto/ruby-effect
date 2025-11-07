#!/usr/bin/env ruby
# typed: false

require_relative "../lib/effect"

PAYMENT_GATEWAY = Effect::DependencyKey.new(:payment_gateway)
LOGGER = Effect::DependencyKey.new(:logger)

module Layers
  Gateway = Effect::Layer.new(description: "payment_gateway") do |_ctx|
    {
      PAYMENT_GATEWAY => lambda do |amount_cents|
        raise ArgumentError, "amount must be positive" if amount_cents <= 0

        sleep(0.02) # pretend to talk to a remote service
        { status: :ok, amount_cents: amount_cents }
      end
    }
  end

  Logger = Effect::Layer.new(description: "logger") do |_ctx|
    {
      LOGGER => ->(message, metadata = {}) { puts "#{message} #{metadata.inspect}" }
    }
  end

  Telemetry = Effect::Layer.new(description: "telemetry wrapper") do |ctx|
    gateway = ctx.fetch(PAYMENT_GATEWAY)
    logger = ctx.fetch(LOGGER) { |_missing| ->(message, metadata = {}) { warn("#{message} #{metadata.inspect}") } }

    instrumented = lambda do |amount_cents|
      logger.call("charge.started", amount_cents: amount_cents)
      Effect::Result.wrap { gateway.call(amount_cents) }.tap do |result|
        if result.success?
          logger.call("charge.succeeded", amount_cents: amount_cents)
        else
          logger.call("charge.failed", cause: result.cause.to_h)
        end
      end.value!
    end

    { payment_gateway: instrumented }
  end
end

module Payments
  def self.charge(amount_cents)
    Effect::Effect.new(description: "payments.charge", requirements: [PAYMENT_GATEWAY]) do |ctx|
      gateway = ctx.fetch(PAYMENT_GATEWAY)
      Effect::Result.wrap { gateway.call(amount_cents) }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  puts "Base behavior (no telemetry):"
  Effect::Runtime.run(
    Payments.charge(1000),
    layers: [Layers::Gateway]
  ).value!

  puts "\nTelemetry added without touching the effect:"
  Effect::Runtime.run(
    Payments.charge(1500),
    layers: [Layers::Gateway, Layers::Logger, Layers::Telemetry]
  ).value!
end
