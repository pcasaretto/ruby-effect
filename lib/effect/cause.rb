# frozen_string_literal: true

module Effect
  # Cause captures the structured failure semantics for a task.
  class Cause
    attr_reader :type, :error, :exception, :backtrace

    def initialize(type:, error: nil, exception: nil, backtrace: nil)
      @type = type
      @error = error
      @exception = exception
      @backtrace = Array(backtrace || exception&.backtrace)
    end

    def self.fail(error)
      new(type: :failure, error: error)
    end

    def self.interrupt(reason = nil)
      new(type: :interrupt, error: reason)
    end

    def self.defect(exception)
      new(type: :defect, exception: exception, backtrace: exception.backtrace)
    end

    def failure?
      type == :failure
    end

    def interrupt?
      type == :interrupt
    end

    def defect?
      type == :defect
    end

    def message
      case type
      when :failure
        "failure: #{error.inspect}"
      when :interrupt
        "interrupt: #{error.inspect}"
      when :defect
        "defect: #{exception.class}: #{exception.message}"
      else
        type.to_s
      end
    end

    def to_s
      message
    end
  end
end
