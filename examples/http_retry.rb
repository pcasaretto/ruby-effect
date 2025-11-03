# frozen_string_literal: true

require_relative "../lib/effect"
require "logger"

include Effect::Prelude

class FlakyClient
  Response = Struct.new(:code, :body)

  def initialize(failures: 2)
    @failures = failures
    @requests = 0
  end

  def get(_path, headers: {})
    @requests += 1
    raise Timeout::Error, "boom" if @requests <= @failures

    Response.new("200", "headers=#{headers.inspect}")
  end
end

layer = Layer.stack(
  Logging.console(level: Logger::INFO),
  Layer.from_value(Effect::Layers::HTTP::KEY, FlakyClient.new())
)

program =
  Layers::HTTP.get("/ping", headers: { "X-Request" => "demo" })
    .retry(Schedule.exponential(base: 0.1, max: 0.2, limit: 5), retry_on: [Timeout::Error])
    .and_then do |response|
      Logging.info { "response=#{response.body}" }.map { response.code }
    end
    .provide_layer(layer)

begin
  puts Effect::Runtime.default.run(program)
rescue Timeout::Error => e
  warn "Request failed after retries: #{e.message}"
end
