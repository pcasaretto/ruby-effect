#!/usr/bin/env ruby
# typed: true

require_relative "../lib/effect"

module Examples
  module PipelineStyle
    extend T::Sig

    LOGGER_SIG = T.type_alias do
      T.proc.params(message: String).void
    end

    DB_SIG = T.type_alias do
      T.proc.params(query: String).returns(T::Hash[Symbol, T.untyped])
    end

    LOGGER = Effect::Keys.define(:logger, type: LOGGER_SIG)
    DB = Effect::Keys.define(:db, type: DB_SIG)

    # ❌ OLD STYLE: Explicit requirements in Effect.new
    def self.get_user_old_style(id)
      Effect::Effect.new(requirements: [LOGGER, DB], description: "get_user") do |ctx|
        logger = T.let(ctx.fetch(LOGGER), LOGGER_SIG)
        db = T.let(ctx.fetch(DB), DB_SIG)

        logger.call("Fetching user #{id}")
        user = db.call("SELECT * FROM users WHERE id = #{id}")
        Effect::Result.success(user)
      end
    end

    # ✅ NEW STYLE: Pipeline-style service access
    def self.get_user_pipeline(id)
      Effect::Effect.service(LOGGER).flat_map do |logger|
        Effect::Effect.service(DB).flat_map do |db|
          logger.call("Fetching user #{id}")
          user = db.call("SELECT * FROM users WHERE id = #{id}")
          Effect::Effect.succeed(user)
        end
      end
    end

    # 🚀 EVEN NICER: Extract services once, use in pure code
    def self.get_user_extracted(id)
      Effect::Effect.service(LOGGER).flat_map do |logger|
        Effect::Effect.service(DB).flat_map do |db|
          # Now we have both services, do pure business logic
          fetch_user(id, logger, db)
        end
      end
    end

    def self.fetch_user(id, logger, db)
      logger.call("Fetching user #{id}")
      user = db.call("SELECT * FROM users WHERE id = #{id}")
      Effect::Effect.succeed(user)
    end

    # Helper for wiring up dependencies
    def self.run_example(effect)
      logger_layer = Effect::Layer.from_hash({
        LOGGER => ->(msg) { puts "[LOG] #{msg}" }
      })

      db_layer = Effect::Layer.from_hash({
        DB => ->(query) { { id: 1, name: "Alice", query: query } }
      })

      result = Effect::Runtime.run(
        effect.provide_layer(logger_layer).provide_layer(db_layer)
      )

      result.value!
    end
  end
end

if $PROGRAM_NAME == __FILE__
  puts "Old style (verbose):"
  user1 = Examples::PipelineStyle.run_example(
    Examples::PipelineStyle.get_user_old_style(1)
  )
  puts "Result: #{user1.inspect}\n\n"

  puts "Pipeline style:"
  user2 = Examples::PipelineStyle.run_example(
    Examples::PipelineStyle.get_user_pipeline(1)
  )
  puts "Result: #{user2.inspect}\n\n"

  puts "Extracted style:"
  user3 = Examples::PipelineStyle.run_example(
    Examples::PipelineStyle.get_user_extracted(1)
  )
  puts "Result: #{user3.inspect}"
end
