# typed: true
# frozen_string_literal: true

require_relative "../lib/effect"
require "logger"

LOGGER_TAG = Effect::Typed.tag(:logger, Logger)

# Intentional mistake: we run the task without providing the required layer.
Effect::Typed.run(
  Effect::Typed.service(LOGGER_TAG)
    .tap { |logger| logger.info("oops") }
)
