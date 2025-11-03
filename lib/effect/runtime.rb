# frozen_string_literal: true

require_relative "runtime/scheduler"
require_relative "runtime/scope"

module Effect
  class Runtime
    class TaskFailure < StandardError
      attr_reader :cause

      def initialize(cause)
        super(cause.message)
        @cause = cause
      end
    end

    class Interrupt < StandardError
      attr_reader :cause

      def initialize(cause)
        super(cause.message)
        @cause = cause
      end
    end

    attr_reader :scheduler

    def initialize(context: Context.empty, scheduler: nil)
      @context = context
      @scheduler = scheduler || Scheduler.detect
    end

    def run(task)
      result = run_result(task)
      return result.value if result.success?

      raise_failure(result.cause)
    end

    def run_result(task)
      result = nil
      @scheduler.run do
        scope = Scope.new(runtime: self, context: @context, scheduler: @scheduler)
        result = scope.run(task)
      end
      result
    end

    def with_context(context)
      previous = @context
      @context = context
      yield
    ensure
      @context = previous
    end

    def self.default
      @default ||= new
    end

    private

    def raise_failure(cause)
      case cause.type
      when :defect
        raise cause.exception
      when :interrupt
        raise Interrupt.new(cause)
      else
        raise TaskFailure.new(cause)
      end
    end
  end
end
