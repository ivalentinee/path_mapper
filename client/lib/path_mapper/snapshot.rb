# frozen_string_literal: true

require 'json'
require 'zip'

module PathMapper
  # A saved session, which is a client idea entirely.
  #
  # The server has no notion of a snapshot. It hands over what it is made of and
  # what has happened, and the assets those name are already public - so a snapshot
  # is those three things in one file, and restoring it is hydration like any other.
  #
  # The layout is deliberately obvious. It is the client's format rather than a
  # documented contract, so the thing that keeps two versions readable to each other
  # is that there is almost nothing to get wrong: a JSON file and a directory.
  class Snapshot
    class Invalid < StandardError
    end

    ENTITIES = 'entities.json'
    STATE = 'state.json'
    ASSETS = 'assets/'

    attr_reader :entities, :state, :assets

    def initialize(entities, state, assets)
      @entities = entities
      @state = state
      @assets = assets
    end

    def self.write(server, directory)
      entities = server.entities.fetch('entities')
      state = server.state
      assets = server.fetch_assets(asset_paths(entities))

      FileUtils.mkdir_p(directory)
      path = File.join(directory, name_for(entities))
      new(entities, state, assets).write_to(path)
      path
    end

    def self.read(path)
      parts = read_parts(path)

      %W[#{ENTITIES} #{STATE}].each do |required|
        raise Invalid, "#{File.basename(path)} has no #{required}" unless parts[:named][required]
      end

      new(parts[:named][ENTITIES], parts[:named][STATE], parts[:assets])
    end

    def self.read_parts(path)
      named = {}
      assets = {}

      Zip::File.open(path) do |zip|
        zip.each do |entry|
          next unless entry.file?

          body = entry.get_input_stream.read

          if [ENTITIES, STATE].include?(entry.name)
            named[entry.name] = JSON.parse(body)
          else
            assets[File.basename(entry.name)] = body
          end
        end
      end

      { named: named, assets: assets }
    end

    def write_to(path)
      Zip::File.open(path, Zip::File::CREATE) do |zip|
        zip.get_output_stream(ENTITIES) { |io| io.write(JSON.pretty_generate(@entities)) }
        zip.get_output_stream(STATE) { |io| io.write(JSON.pretty_generate(@state)) }
        @assets.each do |name, bytes|
          zip.get_output_stream(ASSETS + name) { |io| io.write(bytes) }
        end
      end
      path
    end

    # Every /upload/... an entity names, wherever it sits in the payload.
    def self.asset_paths(entities)
      found = []
      walk(entities) { |value| found << value if value.is_a?(String) && value.start_with?('/upload/') }
      found.uniq
    end

    def self.walk(value, &block)
      case value
      when Hash then value.each_value { |inner| walk(inner, &block) }
      when Array then value.each { |inner| walk(inner, &block) }
      else block.call(value)
      end
    end

    def self.name_for(entities)
      ids = entities.select { |e| %w[adventure group].include?(e['kind']) }.map { |e| e['id'] }
      stamp = Time.now.strftime('%Y%m%dT%H%M%S')
      "snapshot-#{(ids.sort + [stamp]).join('-')}.pmsnapshot"
    end
  end
end
