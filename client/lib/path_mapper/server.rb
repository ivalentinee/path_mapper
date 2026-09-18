# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'net/http'
require 'stringio'
require 'uri'

module PathMapper
  # The only thing here that speaks HTTP.
  #
  # Every route is token-guarded and every failure comes back as {"error": ...},
  # so one place knows how to phrase what went wrong.
  class Server
    class Failed < StandardError
    end

    def initialize(config)
      @config = config
    end

    # An asset is sent under the name its bytes hash to. The server recomputes that
    # hash and refuses a mismatch, which is what keeps content addressing honest.
    def store_asset(name, bytes)
      request = multipart('/api/assets', 'name' => name, 'file' => [name, bytes])
      send_request(request).fetch('path')
    end

    # One route for everything a session is made of, because the server has one.
    def declare(command)
      send_request(json('/api/entities', command))
    end

    def declare_all(commands)
      commands.each { |command| declare(command) }
    end

    def entities
      send_request(Net::HTTP::Get.new(uri('/api/entities')))
    end

    def state
      send_request(Net::HTTP::Get.new(uri('/api/state')))
    end

    def apply_state(state)
      send_request(json('/api/state', state))
    end

    def set_scene_map(name, bytes)
      send_request(multipart('/api/scenes/map', 'file' => [name, bytes]))
    end

    def reset
      send_request(json('/api/reset', {}))
    end

    # Asset bytes are an open resource, served before the router, so fetching them
    # needs no token - which is also why a snapshot can be assembled here at all.
    def fetch_assets(paths)
      paths.to_h do |path|
        response = perform(Net::HTTP::Get.new(uri(path)))
        raise Failed, "Cannot fetch #{path}" unless ok?(response)

        [File.basename(path), response.body]
      end
    end

    private

    def json(path, body)
      request = Net::HTTP::Post.new(uri(path))
      request['content-type'] = 'application/json'
      request.body = JSON.generate(body)
      request
    end

    # Net::HTTPHeader#set_form has built multipart bodies since Ruby 2.1: it
    # generates its own boundary and streams from the IO rather than assembling a
    # String, so a large map never has to be held twice.
    def multipart(path, fields)
      request = Net::HTTP::Post.new(uri(path))
      request.set_form(form_data(fields), 'multipart/form-data')
      request
    end

    def form_data(fields)
      fields.map do |name, value|
        next [name, value] unless value.is_a?(Array)

        filename, bytes = value
        [name, StringIO.new(bytes), { filename: filename, content_type: 'application/octet-stream' }]
      end
    end

    def uri(path)
      URI.parse("#{@config.server}#{path}")
    end

    def send_request(request)
      request['authorization'] = "Bearer #{@config.token}"
      request['accept'] = 'application/json'

      response = perform(request)
      body = parse(response)

      raise Failed, error_of(response, request.path) unless ok?(response)

      body
    end

    def perform(request)
      target = uri('')
      Net::HTTP.start(target.host, target.port, use_ssl: target.scheme == 'https') do |http|
        http.request(request)
      end
    rescue SystemCallError, SocketError => e
      raise Failed, "Cannot reach #{@config.server}: #{e.message}"
    end

    def error_of(response, path)
      parse(response)['error'] || "#{response.code} from #{path}"
    end

    def ok?(response)
      response.is_a?(Net::HTTPSuccess)
    end

    def parse(response)
      JSON.parse(response.body.to_s)
    rescue JSON::ParserError
      { 'error' => "#{response.code} from the server" }
    end
  end
end
