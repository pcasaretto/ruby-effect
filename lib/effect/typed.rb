# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

require_relative "task"
require_relative "layer"
require_relative "runtime"

module Effect
  module Typed
    extend T::Sig

    module Env
      class Base; end

      class Empty < Base; end

      class Need < Base
        extend T::Generic
        Tag = type_member(:out)
        Rest = type_member(:out)
      end

      class Combine < Base
        extend T::Generic
        Left = type_member(:out)
        Right = type_member(:out)
      end
    end

    class Tag
      extend T::Sig
      extend T::Generic

      Value = type_member(:out)

      sig { returns(Symbol) }
      attr_reader :key

      sig { returns(T::Class[Value]) }
      attr_reader :type

      sig { params(key: Symbol, type: T::Class[Value]).void }
      def initialize(key, type)
        @key = key
        @type = type
      end
    end

    class Task
      extend T::Sig
      extend T::Generic

      EnvType = type_member(:out)
      Out = type_member(:out)

      sig { params(effect: Effect::Task).void }
      def initialize(effect)
        @effect = effect
      end

      sig { returns(Effect::Task) }
      def effect
        @effect
      end

      sig do
        type_parameters(:Mapped)
          .params(block: T.proc.params(arg0: Out).returns(T.type_parameter(:Mapped)))
          .returns(Task[EnvType, T.type_parameter(:Mapped)])
      end
      def map(&block)
        new_effect = @effect.map do |value|
          block.call(T.cast(value, Out))
        end

        T.cast(Task.new(new_effect), Task[EnvType, T.type_parameter(:Mapped)])
      end

      sig do
        type_parameters(:NextEnv, :NextOut)
          .params(block: T.proc.params(arg0: Out).returns(Task[T.type_parameter(:NextEnv), T.type_parameter(:NextOut)]))
          .returns(Task[Env::Combine[EnvType, T.type_parameter(:NextEnv)], T.type_parameter(:NextOut)])
      end
      def and_then(&block)
        new_effect = @effect.and_then do |value|
          next_task = block.call(T.cast(value, Out))
          next_task.effect
        end

        T.cast(Task.new(new_effect), Task[Env::Combine[EnvType, T.type_parameter(:NextEnv)], T.type_parameter(:NextOut)])
      end

      alias flat_map and_then

      sig do
        params(block: T.proc.params(arg0: Out).void).returns(Task[EnvType, Out])
      end
      def tap(&block)
        map do |value|
          block.call(value)
          value
        end
      end
    end

    sig do
      type_parameters(:Value)
        .params(key: Symbol, type: T::Class[T.type_parameter(:Value)])
        .returns(Tag[T.type_parameter(:Value)])
    end
    def self.tag(key, type)
      Tag[T.type_parameter(:Value)].new(key, type)
    end

    sig do
      type_parameters(:Value)
        .params(tag: Tag[T.type_parameter(:Value)])
        .returns(Task[Env::Need[Tag[T.type_parameter(:Value)], Env::Empty], T.type_parameter(:Value)])
    end
    def self.service(tag)
      effect = Effect::Task.access(tag.key).and_then do |value|
        if tag.type === value
          Effect::Task.succeed(value)
        else
          Effect::Task.fail(TypeError.new("expected #{tag.type}, got #{value.class}"))
        end
      end

      T.cast(Task.new(effect), Task[Env::Need[Tag[T.type_parameter(:Value)], Env::Empty], T.type_parameter(:Value)])
    end

    sig do
      type_parameters(:Out)
        .params(value: T.type_parameter(:Out))
        .returns(Task[Env::Empty, T.type_parameter(:Out)])
    end
    def self.succeed(value)
      T.cast(Task.new(Effect::Task.succeed(value)), Task[Env::Empty, T.type_parameter(:Out)])
    end

    sig do
      type_parameters(:Out)
        .params(block: T.proc.returns(T.type_parameter(:Out)))
        .returns(Task[Env::Empty, T.type_parameter(:Out)])
    end
    def self.from(&block)
      T.cast(Task.new(Effect::Task.from(&block)), Task[Env::Empty, T.type_parameter(:Out)])
    end

    sig do
      type_parameters(:Value, :RestEnv, :Out)
        .params(task: Task[Env::Need[Tag[T.type_parameter(:Value)], T.type_parameter(:RestEnv)], T.type_parameter(:Out)],
                tag: Tag[T.type_parameter(:Value)],
                layer: Effect::Layer)
        .returns(Task[T.type_parameter(:RestEnv), T.type_parameter(:Out)])
    end
    def self.provide(task, tag, layer)
      provided = task.effect.provide_layer(layer)
      tag
      T.cast(Task.new(provided), Task[T.type_parameter(:RestEnv), T.type_parameter(:Out)])
    end

    sig do
      type_parameters(:EnvParam, :Out)
        .params(task: Task[T.type_parameter(:EnvParam), T.type_parameter(:Out)])
        .returns(Effect::Task)
    end
    def self.to_effect(task)
      task.effect
    end

    sig do
      type_parameters(:Out)
        .params(task: Task[Env::Empty, T.type_parameter(:Out)], runtime: Effect::Runtime)
        .returns(T.type_parameter(:Out))
    end
    def self.run(task, runtime = Effect::Runtime.default)
      runtime.run(task.effect)
    end
  end
end
