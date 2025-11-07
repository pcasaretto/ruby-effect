# typed: true

module Effect
  class FailureError < StandardError
    attr_reader :cause

    def initialize(cause)
      @cause = cause
      super(cause.message || cause.tag.to_s)
      set_backtrace(cause.trace || [])
    end
  end

  class Cause
    attr_reader :tag, :message, :metadata, :exception, :trace

    def self.exception(exception, tag: :exception, message: nil, metadata: {})
      new(
        tag: tag,
        message: message || exception.message,
        metadata: metadata.merge(original_exception_class: exception.class.name),
        exception: exception,
        trace: exception.backtrace
      )
    end

    def initialize(tag:, message: nil, metadata: {}, exception: nil, trace: caller)
      @tag = tag
      @message = message
      @metadata = metadata.freeze
      @exception = exception
      @trace = trace
    end

    def to_h
      {
        tag: tag,
        message: message,
        metadata: metadata,
        exception: exception&.class&.name,
        trace: trace
      }
    end

    def enrich(additional_metadata = {})
      Cause.new(
        tag: tag,
        message: message,
        metadata: metadata.merge(additional_metadata),
        exception: exception,
        trace: trace
      )
    end

    def with_tag(new_tag)
      Cause.new(
        tag: new_tag,
        message: message,
        metadata: metadata,
        exception: exception,
        trace: trace
      )
    end

    def with_message(new_message)
      Cause.new(
        tag: tag,
        message: new_message,
        metadata: metadata,
        exception: exception,
        trace: trace
      )
    end
  end
end
