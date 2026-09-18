# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'minitest/autorun'
require 'tmpdir'
require 'path_mapper'

# The same fixtures the Elixir suite uses, so the two implementations of the
# pipeline are held to one oracle rather than two.
FIXTURES = File.expand_path('../../test/data', __dir__)

def fixture(relative)
  File.join(FIXTURES, relative)
end

def fixtures?
  File.directory?(FIXTURES)
end

# Records what it was asked to store and hands back the paths the server would.
class FakeServer
  attr_reader :assets, :loaded

  def initialize
    @assets = {}
    @loaded = nil
  end

  def store_asset(name, bytes)
    @assets[name] = bytes
    "/upload/#{name}"
  end

  def declare(command)
    @loaded = command
  end

  def declare_all(commands)
    commands.each { |command| declare(command) }
  end
end
