# typed: true

module Effect
  class Layer
    attr_reader :description

    def self.identity
      @identity ||= new(description: "identity") { |_| Context.empty }
    end

    def self.from_hash(hash, description: nil)
      new(description: description) { |_ctx| Context.from_hash(hash) }
    end

    def initialize(description: nil, &builder)
      raise ArgumentError, "builder block is required" unless builder

      @description = description
      @builder = builder
    end

    def build(context = Context.empty)
      raw = @builder.call(context)
      normalize_context(raw)
    rescue FailureError => e
      Result.failure(e.cause)
    rescue StandardError => exception
      Result.failure(
        Cause.exception(
          exception,
          tag: :layer_exception,
          message: "Unhandled exception while building layer#{description ? " (#{description})" : ""}"
        )
      )
    end

    def and_then(other)
      left = self
      Layer.new(description: chain_description(other, "and_then")) do |ctx|
        left.build(ctx).flat_map do |left_ctx|
          merged = ctx.merge(left_ctx)
          other.build(merged).map do |right_ctx|
            left_ctx.merge(right_ctx)
          end
        end
      end
    end

    def +(other)
      and_then(other)
    end

    def provide(effect)
      effect.provide_layer(self)
    end

    private

    def normalize_context(value)
      case value
      when Result
        value.flat_map { |ctx| normalize_context(ctx) }
      when Context
        Result.success(value)
      when Hash
        Result.success(Context.from_hash(value))
      else
        Result.failure(
          Cause.new(
            tag: :invalid_layer_value,
            message: "Layer must return Context, Hash, or Result – got #{value.class}"
          )
        )
      end
    end

    def chain_description(other, operator)
      [description, operator, other.description].compact.join(" ")
    end
  end
end
