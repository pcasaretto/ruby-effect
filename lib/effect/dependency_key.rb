# typed: true

module Effect
  class DependencyKey
    attr_reader :name, :type

    def initialize(name, type: Object)
      @name = name.to_sym
      @type = type
    end

    def eql?(other)
      other.is_a?(DependencyKey) && other.name == name
    end

    alias == eql?

    def hash
      name.hash
    end

    def inspect
      "#<Effect::DependencyKey #{name}>"
    end
  end

  module Keys
    module_function

    def define(name, type: Object)
      DependencyKey.new(name, type: type)
    end
  end
end
