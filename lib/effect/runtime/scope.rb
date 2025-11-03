# frozen_string_literal: true

require "monitor"

module Effect
  class Runtime
    # Scope tracks the current runtime context, ensuring fiber locals and
    # structured supervision remain consistent.
    class Scope
      attr_reader :runtime, :scheduler, :context

      def initialize(runtime:, context:, scheduler:)
        @runtime = runtime
        @context = context
        @scheduler = scheduler
        @monitor = Monitor.new
        @children = []
      end

      def run(task)
        result = Context.with(@context) do
          ensure_result(task.call(self))
        end
        join_children
        result
      rescue StandardError => e
        defect(e)
      end

      def success(value)
        Task::Result.success(value)
      end

      def failure(cause)
        Task::Result.failure(cause)
      end

      def defect(exception)
        failure(Cause.defect(exception))
      end

      def interrupt(reason = nil)
        failure(Cause.interrupt(reason))
      end

      def with_context(new_context)
        previous = @context
        @context = new_context
        Context.with(new_context) { yield }
      ensure
        @context = previous
      end

      def spawn(task)
        parent_context = @context
        handle = @scheduler.async do
          child_scope = Scope.new(runtime: runtime, context: parent_context, scheduler: scheduler)
          Context.with(parent_context) { child_scope.run(task) }
        end

        @monitor.synchronize { @children << handle }
        handle
      end

      def join_children
        handles = nil
        @monitor.synchronize do
          handles = @children.dup
          @children.clear
        end
        handles.each(&:await)
      end

      private

      def ensure_result(result)
        case result
        when Task::Result
          result
        else
          success(result)
        end
      rescue StandardError => e
        defect(e)
      end
    end
  end
end
