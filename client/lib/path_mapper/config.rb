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

    attr_reader :server, :token, :snapshots

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
      MESSAGE
    end

    def initialize(values, path = self.class.path)
      missing = REQUIRED.reject { |key| present?(values[key]) }
      raise Missing, "#{path} has no #{missing.join(' and no ')}" unless missing.empty?

      @server = values['server'].sub(%r{/\z}, '')
      @token = values['token']
      @snapshots = expand(values['snapshots'] || Dir.pwd)
    end

    private

    def present?(value)
      value.is_a?(String) && !value.strip.empty?
    end

    def expand(path)
      File.expand_path(path.sub(%r{\A~(?=/|\z)}, Dir.home))
    end
  end
end
