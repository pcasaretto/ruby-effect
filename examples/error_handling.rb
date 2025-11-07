#!/usr/bin/env ruby
# typed: false

require "json"
require_relative "../lib/effect"

ParseError = Effect::Cause.new(tag: :parse_error, message: "invalid payload")
RemoteFailure = Effect::Cause.new(tag: :remote_failure, message: "service returned non-200")

module Service
  def self.decode_and_fetch(payload)
    Effect::Effect.build(description: "service.decode_and_fetch") do |_ctx|
      Effect::Result.wrap do
        data = JSON.parse(payload)
        raise Effect::FailureError.new(RemoteFailure) unless data["status"] == 200

        data["value"]
      end.map_error do |cause|
        if cause.exception.is_a?(JSON::ParserError)
          ParseError.with_message("payload=#{payload.inspect}")
        else
          cause
        end
      end
    end
  end
end

def safe_service(payload)
  Service.decode_and_fetch(payload).catch_all do |cause|
    Effect::Effect.succeed({ fallback: true, reason: cause.tag })
  end
end

if $PROGRAM_NAME == __FILE__
  puts "Happy path:"
  Effect::Runtime.run(Service.decode_and_fetch({ status: 200, value: 5 }.to_json)).fold(
    on_failure: ->(cause) { warn "failure: #{cause.to_h.inspect}" },
    on_success: ->(value) { puts "value=#{value}" }
  )

  puts "\nBroken JSON:"
  Effect::Runtime.run(Service.decode_and_fetch("not-json")).fold(
    on_failure: ->(cause) { warn "failure: #{cause.to_h.inspect}" },
    on_success: ->(value) { puts "value=#{value}" }
  )

  puts "\nGraceful recovery:"
  Effect::Runtime.run(safe_service({ status: 500 }.to_json)).fold(
    on_failure: ->(cause) { warn "failure: #{cause.to_h.inspect}" },
    on_success: ->(value) { puts "value=#{value.inspect}" }
  )
end
