# frozen_string_literal: true

require 'toml-rb'

module PathMapper
  # What the program needs to know, read from one file on every run.
  #
  # Nothing is *required* from the environment it was started in, because a file
  # manager or a menu entry provides almost none of one. XDG variables are read
  # where the specification defines them and every one has a default, so an empty
  # environment is still a working environment - a discipline rather than an
  # exception to one, and the same discipline desktop/install.sh follows when it
  # writes into XDG_DATA_HOME and XDG_CONFIG_HOME.
  #
  # What never travels in a variable is the configuration itself. The server
  # address and the token live in this file, so there is one place to change them
  # and no credential on a command line for anyone who can list processes.
  class Config
    class Missing < StandardError
    end

    REQUIRED = %w[server token].freeze

    # Keys that used to mean something. A game master who still has one in their
    # file gets told where that thing lives now, because the alternative is
    # quietly writing their snapshots somewhere they will not look.
    RETIRED = {
      'snapshots' => 'snapshots are written to <library>/snapshots'
    }.freeze

    # Generous, because the alternative is worse. A map is the largest thing that
    # crosses the wire and a game master's uplink is not a data centre's, so a read
    # that is merely slow must not be mistaken for one that has died. The connect
    # timeout stays short by comparison: a host that has not answered in half a
    # minute is down, and waiting longer only delays saying so.
    DEFAULTS = { 'open_timeout' => 30, 'read_timeout' => 300, 'write_timeout' => 300 }.freeze

    attr_reader :server, :token, :library, :open_timeout, :read_timeout, :write_timeout

    def self.path
      base = ENV.fetch('XDG_CONFIG_HOME', nil)
      base = File.join(Dir.home, '.config') if base.nil? || base.empty?
      File.join(base, 'pathmapper', 'config.toml')
    end

    # Where a game master's own files live, if they have not said otherwise.
    # XDG's data directory, because a template is neither configuration nor a
    # cache - and overridable, because ~/.local/share is not a place anyone
    # browses and most will point this at their campaign directory instead.
    def self.default_library
      base = ENV.fetch('XDG_DATA_HOME', nil)
      base = File.join(Dir.home, '.local', 'share') if base.nil? || base.empty?
      File.join(base, 'path-mapper')
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
          library = "~/campaigns"

        Optionally, in seconds:

          open_timeout = 30
          read_timeout = 300
          write_timeout = 300
      MESSAGE
    end

    def initialize(values, path = self.class.path)
      @path = path
      require_settings!(values)

      @server = values['server'].sub(%r{/\z}, '')
      @token = values['token']
      @library = library_at(values)
      @retired = RETIRED.keys.select { |key| values.key?(key) }
      @open_timeout, @read_timeout, @write_timeout = timeouts(values)
    end

    # Said once, at the end of the run that read the file, so it does not get
    # lost above a page of progress lines.
    def retired_notice
      return nil if @retired.empty?

      @retired.map { |key| "`#{key}` in #{@path} does nothing now - #{RETIRED[key]}." }.join("\n")
    end

    private

    def require_settings!(values)
      missing = REQUIRED.reject { |key| present?(values[key]) }

      raise Missing, "#{@path} has no #{missing.join(' and no ')}" unless missing.empty?
    end

    def library_at(values)
      Library.new(expand(values['library'] || self.class.default_library))
    end

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
