# frozen_string_literal: true

require 'test_helper'
require 'net/http'
require 'stringio'

# Stands in for a connection so a failure can be produced without a network.
class FakeConnection
  attr_reader :requests

  def initialize(&responder)
    @responder = responder
    @requests = []
    @started = true
  end

  def request(request)
    @requests << request
    @responder.call(request, @requests.length)
  end

  def started? = @started
  def finish = @started = false
end

class ServerTest < Minitest::Test
  def config(values = {})
    PathMapper::Config.new({ 'server' => 'https://example.test', 'token' => 't' }.merge(values))
  end

  def server_on(connection, values = {})
    server = PathMapper::Server.new(config(values))
    server.define_singleton_method(:http) { connection }
    server
  end

  def ok_response
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response.instance_variable_set(:@body, '{"path":"/upload/x.png"}')
    response.instance_variable_set(:@read, true)
    response
  end

  # This is the failure the production upload hit. Net::OpenTimeout is a
  # Timeout::Error, not a SystemCallError, so it used to escape as itself.
  def test_a_connect_timeout_becomes_a_reachability_failure
    connection = FakeConnection.new { raise Net::OpenTimeout, 'execution expired' }

    error = assert_raises(PathMapper::Server::Failed) do
      server_on(connection).declare('kind' => 'adventure')
    end

    assert_includes error.message, 'https://example.test'
    assert_includes error.message, '30s'
  end

  def test_a_read_timeout_says_which_limit_was_reached
    connection = FakeConnection.new { raise Net::ReadTimeout }

    error = assert_raises(PathMapper::Server::Failed) do
      server_on(connection, 'read_timeout' => 120).declare('kind' => 'adventure')
    end

    assert_includes error.message, '120s'
  end

  def test_a_dropped_keep_alive_connection_is_retried_once
    connection = FakeConnection.new do |_request, attempt|
      raise EOFError, 'end of file reached' if attempt == 1

      ok_response
    end

    assert_equal '/upload/x.png', server_on(connection).store_asset('x.png', 'bytes')
    assert_equal 2, connection.requests.length
  end

  # Retrying for ever would turn a server that is refusing connections into a
  # client that never returns.
  # Without rewinding, the second attempt streams a StringIO that the first one
  # already read to EOF, and uploads an empty file under a hash of real bytes.
  def test_a_retried_asset_upload_rewinds_its_body_first
    positions = []

    connection = FakeConnection.new do |request, attempt|
      stream = streams_of(request).first
      positions << stream.pos
      stream.read # what Net::HTTP does to it while encoding the body
      raise EOFError if attempt == 1

      ok_response
    end

    server_on(connection).store_asset('x.png', 'the real bytes')

    assert_equal [0, 0], positions
  end

  # Net::HTTP keeps the IOs it will encode in @body_data and exposes no reader, so
  # this is the only way to see what a second attempt would actually send.
  def streams_of(request)
    request.instance_variable_get(:@body_data).to_a.flatten.grep(StringIO)
  end

  def test_a_connection_that_keeps_dropping_gives_up
    connection = FakeConnection.new { raise Errno::ECONNRESET }

    assert_raises(PathMapper::Server::Failed) { server_on(connection).declare('kind' => 'x') }
    assert_equal 2, connection.requests.length
  end

  def test_a_timeout_is_not_retried
    connection = FakeConnection.new { raise Net::OpenTimeout }

    assert_raises(PathMapper::Server::Failed) { server_on(connection).declare('kind' => 'x') }
    assert_equal 1, connection.requests.length
  end
end
