# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'net/http'
require 'openssl'
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

    # Anything that means "the bytes did not get there", whatever layer noticed.
    # Net::OpenTimeout and Net::ReadTimeout descend from Timeout::Error rather than
    # from SystemCallError, which is why they used to escape as themselves instead
    # of arriving here phrased as a reachability problem.
    UNREACHABLE = [
      SystemCallError, SocketError, IOError, Timeout::Error, OpenSSL::SSL::SSLError
    ].freeze

    # A kept-alive connection the server has since dropped fails on the next write,
    # before that request is processed. Re-sending it is safe here beyond the usual
    # argument about idempotence: an asset is stored under the hash of its bytes and
    # an entity replaces itself by id, so this API has no request that means
    # something different the second time.
    DROPPED = [EOFError, Errno::ECONNRESET, Errno::EPIPE].freeze

    # Shorter than any of the request timeouts, so an idle connection is dropped by
    # this side rather than discovered to be dead by the next upload.
    KEEP_ALIVE = 30

    def initialize(config)
      @config = config
    end

    # Hands back the connection so a caller that is done can stop holding it open.
    def close
      @http&.finish if @http&.started?
      @http = nil
    rescue IOError
      @http = nil
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
    def fetch_assets(paths, progress = Silence.new)
      paths.to_h do |path|
        name = File.basename(path)

        response = progress.step("fetching #{name}") do
          perform(Net::HTTP::Get.new(uri(path)))
        end
        raise Failed, "Cannot fetch #{path}" unless ok?(response)

        [name, response.body]
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
      data = form_data(fields)
      request.set_form(data, 'multipart/form-data')
      rewindable(request, data)
    end

    # Net::HTTP encodes a multipart body at send time, from the IOs it was handed,
    # and does not expose them afterwards. So a retry re-sends a stream already at
    # EOF - an empty file part, which the server then rejects as a hash mismatch,
    # which is a baffling way to fail a connection that only needed reopening.
    # Holding the streams here is what lets the second attempt send the same bytes.
    def rewindable(request, data)
      streams = data.flat_map { |part| part.grep(StringIO) }
      request.define_singleton_method(:rewind_body) { streams.each(&:rewind) }
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

    # One connection for the whole run. Hydrating an adventure is dozens of
    # requests, and opening a TCP connection and a TLS session for each one paid
    # that cost dozens of times and gave every one of them its own chance to time
    # out - which is the likelier reading of a connect timeout that appears partway
    # through an upload than a connect timeout that is merely too short.
    def perform(request, retried: false)
      http.request(request)
    rescue *UNREACHABLE => e
      close
      raise Failed, unreachable(e) if retried || DROPPED.none? { |kind| e.is_a?(kind) }

      request.rewind_body if request.respond_to?(:rewind_body)
      perform(request, retried: true)
    end

    def unreachable(error)
      case error
      when Net::OpenTimeout
        "Cannot reach #{@config.server}: no connection after " \
        "#{@config.open_timeout}s. Is the host up, and is the port open?"
      when Net::ReadTimeout, Net::WriteTimeout
        "#{@config.server} stopped responding after #{@config.read_timeout}s " \
        'part-way through a request. Raise read_timeout if the link is slow.'
      else
        "Cannot reach #{@config.server}: #{error.message}"
      end
    end

    def http
      @http ||= begin
        target = uri('')
        client = Net::HTTP.new(target.host, target.port)
        client.use_ssl = target.scheme == 'https'
        client.open_timeout = @config.open_timeout
        client.read_timeout = @config.read_timeout
        client.write_timeout = @config.write_timeout
        client.keep_alive_timeout = KEEP_ALIVE
        client.start
        client
      end
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
