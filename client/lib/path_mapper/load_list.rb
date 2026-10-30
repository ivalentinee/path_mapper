# frozen_string_literal: true

require 'json'
require 'toml-rb'

module PathMapper
  # Which pieces a session is made of, and where everything starts.
  #
  # The counterpart to a snapshot rather than a variant of it. A snapshot is
  # taken and carries its own bytes, so it still opens when the artwork has
  # changed underneath it. A load list is written, names its pieces, and lets
  # the library answer - so repainting a map that keeps its id reaches every
  # session that names it. That is the point, not a side effect of being
  # smaller.
  #
  # Three optional keys, which between them give the file more than one use
  # without giving it more than one shape:
  #
  #   load       other .pmload files, read before anything here
  #   pieces     references, resolved the way every reference is
  #   game_state the server's own dump, as one opaque string
  #
  # It declares nothing. Everything it names is a file that exists on its own
  # and means the same thing without it - which is also why a character's
  # tokens are absent: the .pmcharacter knows them, and a list that repeated
  # them would be the copy that drifts.
  module LoadList
    class Invalid < StandardError
    end

    module_function

    def read(path)
      text = File.read(path).scrub
      parsed = text.lstrip.start_with?('{') ? JSON.parse(text) : TomlRB.parse(text)

      {
        'load' => Array(parsed['load']),
        'pieces' => Array(parsed['pieces']),
        'game_state' => parsed['game_state']
      }
    rescue JSON::ParserError, TomlRB::ParseError => e
      raise Invalid, "#{File.basename(path)} is neither TOML nor JSON: #{e.message}"
    end

    # The file a reference names: a path against the file holding it, or an id
    # looked up in the library. One level down, a nested list's relative paths
    # are its own, which is the reference rule applied where it was always
    # going to be needed.
    def resolve(reference, from, library, kind = nil)
      return nil if reference.nil? || reference.empty?
      return library&.find(reference, kind) if Id.of(reference) == reference

      candidate = File.expand_path(reference, File.dirname(from))
      File.file?(candidate) ? candidate : nil
    end

    # What `save` writes. Grouped by kind under a comment, because a person
    # reads it; flat, because the client does not need telling what a
    # reference is - the file it resolves to says.
    def render(groups, game_state)
      pieces = groups.flat_map { |kind, entries| ["  # #{kind}s"] + entries.map { |e| entry(e) } }

      <<~TOML
        pieces = [
        #{pieces.join("\n")}
        ]

        game_state = #{JSON.generate(game_state).dump}
      TOML
    end

    # The name travels as a comment and is never read back, so one that has
    # gone stale is wrong in a comment rather than wrong in a session.
    def entry(entity)
      named = entity['name'] || entity['character_name']
      comment = named ? " # #{named}" : nil

      %(  "#{entity['id']}",#{comment})
    end
  end
end
