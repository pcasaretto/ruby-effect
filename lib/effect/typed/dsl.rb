# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Effect
  module Typed
    module DSL
      extend T::Sig

      sig do
        type_parameters(:EnvParam, :OutParam)
          .params(block: T.proc.params(arg0: Builder[T.type_parameter(:EnvParam), T.type_parameter(:OutParam)]).returns(T.type_parameter(:OutParam)))
          .returns(Task[T.type_parameter(:EnvParam), T.type_parameter(:OutParam)])
      end
      def self.build(&block)
        builder = Builder.new
        builder.instance_exec(builder, &block)
        T.cast(builder.task, Task[T.type_parameter(:EnvParam), T.type_parameter(:OutParam)])
      end

      class Builder
        extend T::Sig

        sig { void }
        def initialize
          @task = T.let(Typed.succeed(nil), Task[Env::Empty, T.nilable(T.untyped)])
          @last_value = T.let(nil, T.nilable(T.untyped))
        end

        sig { returns(Task[Env::Base, T.untyped]) }
        attr_reader :task

        sig do
          type_parameters(:Value)
            .params(tag: Tag[T.type_parameter(:Value)])
            .returns(T.type_parameter(:Value))
        end
        def service(tag)
          bind(Typed.service(tag))
        end

        sig do
          type_parameters(:Value)
            .params(block: T.proc.returns(T.type_parameter(:Value)))
            .returns(T.type_parameter(:Value))
        end
        def from(&block)
          bind(Typed.from(&block))
        end

        sig do
          type_parameters(:EnvParam, :OutParam)
            .params(task: Task[T.type_parameter(:EnvParam), T.type_parameter(:OutParam)])
            .returns(T.type_parameter(:OutParam))
        end
        def bind(task)
          @task = @task.and_then do |_value|
            task
          end

          @last_value = Effect::Typed.to_effect(task).run(Effect::Runtime.default)
          T.cast(@last_value, T.type_parameter(:OutParam))
        end
      end
    end
  end
end
