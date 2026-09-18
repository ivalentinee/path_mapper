# frozen_string_literal: true

require 'toml-rb'

module PathMapper
  # What the program needs to know, read from one file on every run.
  #
  # Nothing comes from the environment it was started in, because neither GIMP nor
  # a file manager reliably provides one. XDG_CONFIG_HOME is the single exception:
  # it says where the configuration lives, not what is in it.
  class Config
    class Missing < StandardError
    end

    REQUIRED = %w[server token].freeze

    # Generous, because the alternative is worse. A map is the largest thing that
    # crosses the wire and a game master's uplink is not a data centre's, so a read
    # that is merely slow must not be mistaken for one that has died. The connect
    # timeout stays short by comparison: a host that has not answered in half a
    # minute is down, and waiting longer only delays saying so.
    DEFAULTS = { 'open_timeout' => 30, 'read_timeout' => 300, 'write_timeout' => 300 }.freeze

    attr_reader :server, :token, :snapshots, :open_timeout, :read_timeout, :write_timeout

    def self.path
      base = ENV.fetch('XDG_CONFIG_HOME', nil)
      base = File.join(Dir.home, '.config') if base.nil? || base.empty?
      File.join(base, 'pathmapper', 'config.toml')
    end

    def self.load(path = self.path)
      raise Missing, missing_file_message(path) unless File.exist?(path)

      new(TomlRB.load_file(path), path)
    end

    def self.missing_file_message(path)
      <<~MESSAGE.strip
        No configuration at #{path}

        Create it with:

          server = "http://localhost:4000"
          token = "your upload token"
          snapshots = "~/snapshots"

        Optionally, in seconds:

          open_timeout = 30
          read_timeout = 300
          write_timeout = 300
      MESSAGE
    end

    def initialize(values, path = self.class.path)
      missing = REQUIRED.reject { |key| present?(values[key]) }
      raise Missing, "#{path} has no #{missing.join(' and no ')}" unless missing.empty?

      @server = values['server'].sub(%r{/\z}, '')
      @token = values['token']
      @snapshots = expand(values['snapshots'] || Dir.pwd)
      @open_timeout, @read_timeout, @write_timeout = timeouts(values)
    end

    private

    def timeouts(values)
      DEFAULTS.keys.map { |key| seconds(values, key) }
    end

    # A timeout of zero or less is Net::HTTP's way of spelling "never give up", and
    # a client that hangs for ever is the failure this exists to prevent.
    def seconds(values, key)
      given = values[key]
      return DEFAULTS.fetch(key) unless given.is_a?(Numeric) && given.positive?

      given
    end

    def present?(value)
      value.is_a?(String) && !value.strip.empty?
    end

    def expand(path)
      File.expand_path(path.sub(%r{\A~(?=/|\z)}, Dir.home))
    end
  end
end
