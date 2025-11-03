# frozen_string_literal: true

module Effect
  class Task
    class Result
      attr_reader :status, :value, :cause

      def initialize(status:, value: nil, cause: nil)
        @status = status
        @value = value
        @cause = cause
      end

      def self.success(value)
        new(status: :success, value: value)
      end

      def self.failure(cause)
        new(status: :failure, cause: cause)
      end

      def success?
        status == :success
      end

      def failure?
        status == :failure
      end

      def value!
        raise "task did not succeed" unless success?

        value
      end
    end

    class ForkHandle
      def initialize(handle)
        @handle = handle
      end

      def await
        @handle.await
      end

      def wait
        await
      end

      def join
        Task.new { |_scope| await }
      end
    end

    def initialize(&block)
      raise ArgumentError, "Effect::Task requires a block" unless block

      @program = block
    end

    def call(scope)
      @program.call(scope)
    end

    def self.succeed(value = nil)
      new { |scope| scope.success(value) }
    end

    def self.fail(error)
      cause = error.is_a?(Cause) ? error : Cause.fail(error)
      new { |scope| scope.failure(cause) }
    end

    def self.from(&block)
      raise ArgumentError, "Effect::Task.from requires a block" unless block

      new do |scope|
        begin
          scope.success(block.call)
        rescue StandardError => e
          scope.defect(e)
        end
      end
    end

    def map
      raise ArgumentError, "map expects a block" unless block_given?

      Task.new do |scope|
        result = call(scope)
        if result.success?
          begin
            scope.success(yield(result.value))
          rescue StandardError => e
            scope.defect(e)
          end
        else
          result
        end
      end
    end

    def and_then
      raise ArgumentError, "and_then expects a block" unless block_given?

      Task.new do |scope|
        result = call(scope)
        next result unless result.success?

        begin
          next_task = yield(result.value)
        rescue StandardError => e
          next scope.defect(e)
        end

        unless next_task.is_a?(Task)
          next scope.defect(TypeError.new("expected Effect::Task from and_then, got #{next_task.inspect}"))
        end

        next_task.call(scope)
      end
    end

    alias flat_map and_then

    def rescue(*klasses)
      raise ArgumentError, "rescue expects a block" unless block_given?

      Task.new do |scope|
        result = call(scope)
        next result if result.success?

        if matches?(result.cause, klasses)
          begin
            recovered = yield(result.cause)
          rescue StandardError => e
            next scope.defect(e)
          end

          unless recovered.is_a?(Task)
            next scope.defect(TypeError.new("expected Effect::Task from rescue block, got #{recovered.inspect}"))
          end

          recovered.call(scope)
        else
          result
        end
      end
    end

    def tap
      raise ArgumentError, "tap expects a block" unless block_given?

      map do |value|
        yield(value)
        value
      end
    end

    def provide(key, value)
      provide_all(key => value)
    end

    def provide_all(values)
      Task.new do |scope|
        new_context = scope.context.merge(values)
        scope.with_context(new_context) { call(scope) }
      end
    end

    def provide_context(context)
      Task.new do |scope|
        scope.with_context(context) { call(scope) }
      end
    end

    def provide_layer(layer)
      Task.new do |scope|
        build = layer.call(scope)
        next build unless build.success?

        provision = Layer.ensure_provision(build.value)
        new_context = Layer.apply_context(scope.context, provision.context)

        begin
          scope.with_context(new_context) { call(scope) }
        ensure
          Layer.run_finalizers(provision.finalizers, scope)
        end
      end
    end

    def fork
      Task.new do |scope|
        handle = scope.spawn(self)
        scope.success(ForkHandle.new(handle))
      end
    end

    def self.fork(task)
      task.fork
    end

    def retry(schedule, retry_on: nil)
      Task.new do |scope|
        enumerator = schedule.respond_to?(:enumerator) ? schedule.enumerator : schedule.to_enum
        result = call(scope)

        while result.failure? && retry_match?(result.cause, retry_on)
          begin
            delay = enumerator.next
          rescue StopIteration
            break
          end

          sleep(delay.to_f) if delay && delay.positive?
          result = call(scope)
        end

        result
      end
    end

    def run(runtime = Runtime.default)
      runtime.run(self)
    end

    def result(runtime = Runtime.default)
      runtime.run_result(self)
    end

    def self.access(key)
      new do |scope|
        begin
          scope.success(scope.context.fetch(key))
        rescue KeyError => e
          scope.failure(Cause.fail(e))
        end
      end
    end

    def self.access_all
      new { |scope| scope.success(scope.context.to_h) }
    end

    def self.defer(&block)
      raise ArgumentError, "defer expects a block" unless block

      new do |scope|
        scope.success(block)
      end
    end

    private

    def matches?(cause, klasses)
      return true if klasses.empty?

      target = cause.failure? ? cause.error : cause.exception
      klasses.any? { |klass| klass === target }
    end

    def retry_match?(cause, retry_on)
      return true unless retry_on

      Array(retry_on).any? { |matcher| matcher === (cause.failure? ? cause.error : cause.exception) }
    end
  end
end
