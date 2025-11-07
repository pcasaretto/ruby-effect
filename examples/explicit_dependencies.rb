#!/usr/bin/env ruby
# typed: false

require_relative "../lib/effect"

USER_REPO = Effect::DependencyKey.new(:user_repo)
MAILER = Effect::DependencyKey.new(:mailer)

module Layers
  UserRepo = Effect::Layer.new(description: "user_repo") do |_ctx|
    {
      USER_REPO => lambda do |id|
        { id: id, email: "user#{id}@example.com" }
      end
    }
  end

  Mailer = Effect::Layer.new(description: "mailer") do |_ctx|
    {
      MAILER => lambda do |email, body|
        puts "Sending email to #{email.inspect}: #{body}"
      end
    }
  end
end

module Newsletter
  def self.send(user_id)
    Effect::Effect.service(USER_REPO).flat_map do |repo|
      Effect::Effect.service(MAILER).flat_map do |mailer|
        Effect::Effect.attempt do
          user = repo.call(user_id)
          mailer.call(user[:email], "Welcome to the newsletter!")
          { delivered_to: user[:email] }
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  puts "Production run:"
  Effect::Runtime.run(Newsletter.send(1), layers: [Layers::UserRepo, Layers::Mailer])

  puts "\nTest with fakes:"
  deliveries = []
  fake_layer = Effect::Layer.from_hash({
    USER_REPO => ->(_id) { { email: "test@example.com" } },
    MAILER => ->(email, body) { deliveries << [email, body] }
  })

  Effect::Runtime.run(Newsletter.send(42), layers: [fake_layer])
  p deliveries
end
