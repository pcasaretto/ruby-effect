# frozen_string_literal: true

require "net/http"
require "uri"

module Effect
  module Layers
    module HTTP
      KEY = :http_client

      def self.client(base_uri:, open_timeout: 5, read_timeout: 10, default_headers: {})
        Layer.from_value(KEY, Client.new(base_uri, open_timeout: open_timeout, read_timeout: read_timeout, default_headers: default_headers))
      end

      def self.get(path, headers: {})
        with_client do |client|
          Task.from { client.get(path, headers: headers) }
        end
      end

      def self.post(path, body:, headers: {})
        with_client do |client|
          Task.from { client.post(path, body: body, headers: headers) }
        end
      end

      def self.with_client
        Task.access(KEY).and_then do |client|
          task = yield(client)
          unless task.is_a?(Task)
            Task.fail(TypeError.new("expected Effect::Task from HTTP client block, got #{task.inspect}"))
          else
            task
          end
        end
      end

      class Client
        attr_reader :base_uri, :open_timeout, :read_timeout, :default_headers

        def initialize(base_uri, open_timeout:, read_timeout:, default_headers: {})
          @base_uri = URI(base_uri)
          @open_timeout = open_timeout
          @read_timeout = read_timeout
          @default_headers = default_headers
        end

        def get(path, headers: {})
          request(Net::HTTP::Get, path, headers: headers)
        end

        def post(path, body:, headers: {})
          request(Net::HTTP::Post, path, body: body, headers: headers)
        end

        def request(klass, path, body: nil, headers: {})
          uri = base_uri + path
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = open_timeout
          http.read_timeout = read_timeout

          request = klass.new(uri)
          merged = default_headers.merge(headers)
          merged.each { |key, value| request[key] = value }
          request.body = body if body

          http.start do |h|
            h.request(request)
          end
        end
      end
    end
  end
end
