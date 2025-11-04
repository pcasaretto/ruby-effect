# typed: true
# frozen_string_literal: true

require_relative "../lib/effect"
require "logger"

LOGGER_TAG = Effect::Typed.tag(:logger, Logger)

program = Effect::Typed.service(LOGGER_TAG)
  .tap { |logger| logger.info("typed hello") }

with_logger = Effect::Typed.provide(
  program,
  LOGGER_TAG,
  Effect::Layers::Logging.console(level: Logger::INFO)
)

Effect::Typed.run(with_logger)
