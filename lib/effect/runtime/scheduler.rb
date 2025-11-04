# frozen_string_literal: true

begin
  require "async"
rescue LoadError
  # Async is optional; if missing we fall back to the inline scheduler.
end

module Effect
  class Runtime
    # Scheduler abstracts over the underlying async executor.
    class Scheduler
      def self.detect
        if Object.const_defined?(:Async) && Object.const_get(:Async).const_defined?(:Task)
          AsyncScheduler.new
        else
          InlineScheduler.new
        end
      end

      def run(&block)
        raise NotImplementedError, "subclasses must implement #run"
      end

      def async(&block)
        raise NotImplementedError, "subclasses must implement #async"
      end
    end

    # Handle represents a joinable asynchronous computation.
    class Scheduler::Handle
      def initialize(joinable, awaiter)
        @joinable = joinable
        @awaiter = awaiter
      end

      def await
        @awaiter.call(@joinable)
      end

      alias wait await
    end

    # InlineScheduler executes work on the current thread and uses background
    # threads for ad-hoc concurrency.
    class InlineScheduler < Scheduler
      def run(&block)
        block.call
      end

      def async(&block)
        thread = Thread.new(&block)
        Scheduler::Handle.new(thread, ->(thr) { thr.value })
      end
    end

    if Object.const_defined?(:Async) && Object.const_get(:Async).const_defined?(:Task)
      # AsyncScheduler delegates to the async gem, giving us fiber-based concurrency.
      class AsyncScheduler < Scheduler
        def run(&block)
          result = nil
          async = Object.const_get(:Async)
          reactor = async.const_get(:Reactor).new
          reactor.async do |task|
            @root = task
            result = block.call
          ensure
            @root = nil
          end
          reactor.run
          result
        ensure
          @root = nil
        end

        def async(&block)
          raise "Async scheduler not running" unless @root

          handle = @root.async(&block)
          Scheduler::Handle.new(handle, ->(task) { task.wait })
        end
      end
    end
  end
end
