# frozen_string_literal: true

module Effect
  class Layer
    Provision = Struct.new(:context, :finalizers, keyword_init: true) do
      def initialize(context:, finalizers: [])
        super(context: context, finalizers: Array(finalizers).compact)
      end

      def add_finalizers(extra)
        Layer::Provision.new(context: context, finalizers: finalizers + Array(extra).compact)
      end
    end

    def initialize(&block)
      raise ArgumentError, "Effect::Layer requires a block" unless block

      @builder = block
    end

    def call(scope)
      result = @builder.call(scope)
      return result if result.is_a?(Task::Result)

      scope.success(result)
    end

    def +(other)
      Layer.new do |scope|
        first = call(scope)
        next first unless first.success?

        first_provision = Layer.ensure_provision(first.value)
        interim_context = Layer.apply_context(scope.context, first_provision.context)

        scope.with_context(interim_context) do
          second = other.call(scope)
          next second unless second.success?

          second_provision = Layer.ensure_provision(second.value)
          combined_context = Layer.apply_context(interim_context, second_provision.context)
          combined_finalizers = second_provision.finalizers + first_provision.finalizers
          scope.success(Provision.new(context: Layer.relative_context(scope.context, combined_context),
                                      finalizers: combined_finalizers))
        end
      end
    end

    def provide_to(task)
      task.provide_layer(self)
    end

    def self.identity
      new do |scope|
        scope.success(Provision.new(context: Context.empty))
      end
    end

    def self.from_value(key, value)
      new do |scope|
        scope.success(Provision.new(context: Context.new(key => value)))
      end
    end

    def self.from_hash(values)
      new do |scope|
        scope.success(Provision.new(context: Context.new(values)))
      end
    end

    def self.from_resource(key, &acquire)
      raise ArgumentError, "from_resource expects a block" unless acquire

      new do |scope|
        begin
          resource, finalizer = acquire.call(scope)
          delta = Context.new(key => resource)
          finalizer_task = coerce_finalizer(finalizer, resource)
          scope.success(Provision.new(context: delta, finalizers: finalizer_task ? [finalizer_task] : []))
        rescue StandardError => e
          scope.defect(e)
        end
      end
    end

    def self.stack(*layers)
      layers.reduce(identity) { |acc, layer| acc + layer }
    end

    def self.apply_context(base, addition)
      case addition
      when nil
        base
      when Context
        base.merge(addition)
      when Hash
        base.merge(addition)
      else
        raise ArgumentError, "cannot apply context from #{addition.class}"
      end
    end

    def self.relative_context(_root, merged)
      case merged
      when Context
        Context.new(merged.to_h)
      when Hash
        Context.new(merged)
      else
        raise ArgumentError, "cannot derive context from #{merged.inspect}"
      end
    end

    def self.ensure_provision(value)
      case value
      when Provision
        value
      when Context
        Provision.new(context: value)
      when Hash
        Provision.new(context: Context.new(value))
      else
        raise TypeError, "expected Layer::Provision, Context, or Hash, got #{value.inspect}"
      end
    end

    def self.run_finalizers(finalizers, scope)
      finalizers.each do |finalizer|
        task = finalizer.is_a?(Task) ? finalizer : Task.from { finalizer.call }
        task.call(scope)
      end
    end

    def self.coerce_finalizer(finalizer, resource = nil)
      case finalizer
      when nil
        nil
      when Task
        finalizer
      when Proc
        if finalizer.arity.zero?
          Task.from { finalizer.call }
        else
          Task.from { finalizer.call(resource) }
        end
      else
        raise ArgumentError, "unsupported finalizer #{finalizer.inspect}"
      end
    end
  end
end
