# frozen_string_literal: true

require "logger"

module Effect
  module Layers
    module Logging
      KEY = :logger

      def self.layer(level: ::Logger::INFO, io: $stdout, formatter: nil, progname: nil)
        Layer.from_resource(KEY) do |_scope|
          logger = ::Logger.new(io)
          logger.level = level
          logger.progname = progname if progname
          logger.formatter = formatter if formatter

          finalizer = lambda do
            next unless logger.respond_to?(:close)

            unless io.equal?($stdout) || io.equal?($stderr)
              logger.close
            end
          end

          [logger, finalizer]
        end
      end

      def self.console(level: ::Logger::INFO)
        layer(level: level, io: $stdout)
      end

      def self.null
        Layer.from_value(KEY, NullLogger.new)
      end

      def self.log(level, message = nil, &block)
        Task.access(KEY).and_then do |logger|
          Task.from do
            payload = message || (block && block.call)
            logger.public_send(level) { payload }
            payload
          end
        end
      end

      def self.info(message = nil, &block)
        log(:info, message, &block)
      end

      def self.warn(message = nil, &block)
        log(:warn, message, &block)
      end

      def self.error(message = nil, &block)
        log(:error, message, &block)
      end

      def self.debug(message = nil, &block)
        log(:debug, message, &block)
      end

      class NullLogger
        def method_missing(_name, *_args)
          self
        end

        def respond_to_missing?(*_args)
          true
        end
      end
    end
  end
end
