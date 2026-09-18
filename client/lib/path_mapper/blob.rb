# frozen_string_literal: true

require 'zip'
require 'toml-rb'

module PathMapper
  # A blob, unpacked in memory.
  #
  # The unpacked form never reaches disk and never outlives the run. The server
  # sees the entries, one at a time; it never sees the archive.
  class Blob
    class Invalid < StandardError
    end

    MANIFEST = 'manifest.toml'

    attr_reader :path, :entries

    def self.open(path)
      new(path, read_entries(path))
    end

    def self.read_entries(path)
      entries = {}
      Zip::File.open(path) do |zip|
        zip.each { |entry| entries[entry.name] = entry.get_input_stream.read if entry.file? }
      end
      entries
    rescue Zip::Error => e
      raise Invalid, "#{File.basename(path)} is not a readable archive: #{e.message}"
    end

    def initialize(path, entries)
      @path = path
      @entries = entries
    end

    def manifest
      raise Invalid, "#{File.basename(@path)} has no #{MANIFEST}" unless @entries.key?(MANIFEST)

      TomlRB.parse(manifest_text)
    rescue TomlRB::ParseError => e
      raise Invalid, "#{File.basename(@path)}: #{MANIFEST} is not valid TOML: #{e.message}"
    end

    # Zip entries are read as bytes, which is right for an image and wrong for the
    # manifest: TOML is UTF-8 by specification. Left as bytes, every string the
    # parser returns is tagged BINARY, and handing one of those to JSON.generate
    # warns today and raises under json 3 - which only shows up once a name carries
    # something outside ASCII, such as a combining accent.
    def manifest_text
      text = @entries.fetch(MANIFEST).dup.force_encoding(Encoding::UTF_8)
      return text if text.valid_encoding?

      raise Invalid, "#{File.basename(@path)}: #{MANIFEST} is not valid UTF-8"
    end

    # Everything that is not the manifest is an asset.
    def assets
      @entries.reject { |name, _bytes| name == MANIFEST }
    end

    # A blob's id comes from its own filename, and a blob without one cannot be
    # described. Caught here so the message names the file, rather than reaching
    # the server as a null and coming back as a schema error.
    def id
      Id.of(@path) ||
        raise(Invalid, "#{filename} carries no id in its name (expected e.g. tt0001-0000000001-...)")
    end

    def filename
      File.basename(@path)
    end
  end
end
