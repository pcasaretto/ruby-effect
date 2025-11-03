# frozen_string_literal: true

module Effect
  class Schedule
    include Enumerable

    def initialize(&factory)
      @factory = factory || -> { Enumerator.new { |_y| } }
    end

    def each(&block)
      enumerator.each(&block)
    end

    def enumerator
      enum = @factory.call
      raise ArgumentError, "schedule factory must return Enumerator" unless enum.is_a?(Enumerator)

      enum
    end

    def limited(limit)
      base_factory = @factory
      Schedule.new do
        base_enum = base_factory.call
        Enumerator.new do |y|
          count = 0
          loop do
            break if limit && count >= limit

            y << base_enum.next
            count += 1
          end
        rescue StopIteration
          # finish naturally
        end
      end
    end

    def self.fixed(interval, limit: nil)
      Schedule.new do
        Enumerator.new do |y|
          count = 0
          loop do
            break if limit && count >= limit

            y << interval
            count += 1
          end
        end
      end
    end

    def self.exponential(base:, factor: 2.0, max: nil, limit: nil)
      Schedule.new do
        Enumerator.new do |y|
          current = base
          count = 0
          loop do
            break if limit && count >= limit

            y << current
            count += 1
            current = current * factor
            current = max if max && current > max
          end
        end
      end
    end

    def self.fibonacci(base: 0.1, limit: nil)
      Schedule.new do
        Enumerator.new do |y|
          a = base
          b = base
          count = 0
          loop do
            break if limit && count >= limit

            y << a
            count += 1
            a, b = b, a + b
          end
        end
      end
    end

    def self.recursions(limit)
      fixed(0, limit: limit)
    end
  end
end
