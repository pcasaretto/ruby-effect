# frozen_string_literal: true

require "monitor"

module Effect
  module Layers
    module Persistence
      KEY = :persistence_store

      def self.memory(seed: {})
        Layer.from_value(KEY, MemoryStore.new(seed))
      end

      def self.with_store
        Task.access(KEY).and_then do |store|
          Task.from { yield(store) }
        end
      end

      def self.insert(table, row)
        with_store { |store| store.insert(table, row) }
      end

      def self.find(table)
        with_store { |store| store.find(table) { |row| yield(row) } }
      end

      def self.all(table)
        with_store { |store| store.all(table) }
      end

      class MemoryStore
        def initialize(seed = {})
          @data = Hash.new { |hash, table| hash[table] = [] }
          seed.each { |table, rows| @data[table] = Array(rows).map(&:dup) }
          @lock = Monitor.new
        end

        def insert(table, row)
          @lock.synchronize do
            @data[table] << row.dup
            row
          end
        end

        def find(table)
          @lock.synchronize do
            @data[table].find { |row| yield(row) }&.dup
          end
        end

        def all(table)
          @lock.synchronize do
            @data[table].map(&:dup)
          end
        end
      end
    end
  end
end
