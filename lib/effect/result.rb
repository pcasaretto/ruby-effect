# typed: true

module Effect
  class Result
    attr_reader :value, :cause

    def self.wrap
      new(:ok, yield, nil)
    rescue FailureError => e
      failure(e.cause)
    rescue StandardError => exception
      failure(Cause.exception(exception))
    end

    def self.success(value)
      new(:ok, value, nil)
    end

    def self.failure(cause)
      raise ArgumentError, "cause must be a Cause" unless cause.is_a?(Cause)

      new(:error, nil, cause)
    end

    def initialize(status, value, cause)
      @status = status
      @value = value
      @cause = cause
    end

    def success?
      @status == :ok
    end

    def failure?
      @status == :error
    end

    def map
      return self unless success?

      Result.success(yield(value))
    rescue FailureError => e
      Result.failure(e.cause)
    rescue StandardError => exception
      Result.failure(Cause.exception(exception, tag: :result_map))
    end

    def flat_map
      return self unless success?

      result = yield(value)
      unless result.is_a?(Result)
        return Result.failure(
          Cause.new(tag: :invalid_result, message: "Expected Result from flat_map, got #{result.class}")
        )
      end

      result
    rescue FailureError => e
      Result.failure(e.cause)
    rescue StandardError => exception
      Result.failure(Cause.exception(exception, tag: :result_flat_map))
    end

    def map_error
      return self unless failure?

      new_cause = yield(cause)
      unless new_cause.is_a?(Cause)
        return Result.failure(
          Cause.new(tag: :invalid_cause, message: "map_error expects a Cause, got #{new_cause.inspect}")
        )
      end

      Result.failure(new_cause)
    rescue FailureError => e
      Result.failure(e.cause)
    rescue StandardError => exception
      Result.failure(Cause.exception(exception, tag: :result_map_error))
    end

    def fold(on_failure:, on_success:)
      if success?
        on_success.call(value)
      else
        on_failure.call(cause)
      end
    end

    def value!
      return value if success?

      raise FailureError.new(cause)
    end
  end
end
