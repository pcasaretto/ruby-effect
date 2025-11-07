#!/usr/bin/env ruby
# typed: false

require_relative "../lib/effect"

USER_GATEWAY = Effect::DependencyKey.new(:user_gateway)

module Legacy
  class UsersGateway
    def initialize(records)
      @records = records
    end

    def call(id)
      record = @records[id]
      raise KeyError, "user #{id} missing" unless record

      record
    end
  end

  module Views
    module_function

    def render(user)
      "User ##{user[:id]} - #{user[:name]}"
    end
  end

  class Controller
    def initialize(gateway:)
      @gateway = gateway
    end

    def show(id)
      context = Effect::Context.from_hash(USER_GATEWAY => @gateway)

      Effect::Interop.run(Effects.rendered_profile(id), context: context).fold(
        on_failure: ->(cause) { "HTTP 404 #{cause.tag}: #{cause.message}" },
        on_success: ->(view) { "HTTP 200 #{view}" }
      )
    end
  end
end

module Effects
  def self.fetch_profile(id)
    Effect::Effect.new(description: "profiles.fetch", requirements: [USER_GATEWAY]) do |ctx|
      gateway = ctx.fetch(USER_GATEWAY)
      Effect::Result.wrap { gateway.call(id) }
    end
  end

  def self.rendered_profile(id)
    fetch_profile(id).map { |user| Legacy::Views.render(user) }
  end
end

if $PROGRAM_NAME == __FILE__
  gateway = Legacy::UsersGateway.new(
    1 => { id: 1, name: "Ada" },
    2 => { id: 2, name: "Grace" }
  )

  controller = Legacy::Controller.new(gateway: gateway)

  puts "Existing controller keeps returning strings:"
  puts controller.show(1)

  puts "\nEffect pipeline reuses legacy renderer:"
  Effect::Interop.run(
    Effects.rendered_profile(2),
    context: Effect::Context.from_hash(USER_GATEWAY => gateway)
  ).fold(
    on_failure: ->(cause) { warn "failure: #{cause.to_h.inspect}" },
    on_success: ->(view) { puts view }
  )

  puts "\nFailure is surfaced as data but controller can still respond imperatively:"
  puts controller.show(99)
end
