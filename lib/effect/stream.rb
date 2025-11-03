# frozen_string_literal: true

module Effect
  class Stream
    include Enumerable

    def initialize(&producer)
      raise ArgumentError, "Effect::Stream requires a block" unless producer

      @producer = producer
    end

    def each(&block)
      enumerator.each(&block)
    end

    def enumerator
      enum = @producer.call
      return enum if enum.is_a?(Enumerator)

      Enumerator.new do |y|
        enum.each { |value| y << value }
      end
    end

    def map
      raise ArgumentError, "map expects a block" unless block_given?

      Stream.new do
        Enumerator.new do |y|
          enumerator.each { |value| y << yield(value) }
        end
      end
    end

    def filter
      raise ArgumentError, "filter expects a block" unless block_given?

      Stream.new do
        Enumerator.new do |y|
          enumerator.each do |value|
            y << value if yield(value)
          end
        end
      end
    end

    def chunk(size)
      Stream.new do
        Enumerator.new do |y|
          buffer = []
          enumerator.each do |value|
            buffer << value
            if buffer.size >= size
              y << buffer
              buffer = []
            end
          end
          y << buffer unless buffer.empty?
        end
      end
    end

    def flat_map
      raise ArgumentError, "flat_map expects a block" unless block_given?

      Stream.new do
        Enumerator.new do |y|
          enumerator.each do |value|
            Array(yield(value)).each { |inner| y << inner }
          end
        end
      end
    end

    def take(limit)
      Stream.new do
        Enumerator.new do |y|
          enumerator.take(limit).each { |value| y << value }
        end
      end
    end

    def zip(other)
      Stream.new do
        Enumerator.new do |y|
          enum_a = enumerator
          enum_b = other.enumerator
          loop do
            y << [enum_a.next, enum_b.next]
          end
        rescue StopIteration
          # exit
        end
      end
    end

    def to_task
      Task.from { enumerator.to_a }
    end

    def self.from_array(array)
      Stream.new { array.to_enum }
    end

    def self.repeat(value)
      Stream.new do
        Enumerator.new do |y|
          loop { y << value }
        end
      end
    end

    def self.from_task(task)
      Stream.new do
        Enumerator.new do |y|
          result = task.result
          if result.success?
            y << result.value
          end
        end
      end
    end

    def self.merge(*streams)
      Stream.new do
        Enumerator.new do |y|
          enumerators = streams.map(&:enumerator)
          loop do
            active = false
            enumerators.each do |enum|
              next if enum.nil?

              begin
                y << enum.next
                active = true
              rescue StopIteration
                # drop exhausted enumerators
              end
            end
            break unless active
          end
        end
      end
    end
  end
end
