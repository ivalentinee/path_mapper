# frozen_string_literal: true

require 'json'
require 'toml-rb'

module PathMapper
  # Someone in the game, read out of a file they are declared in.
  #
  # A character is the one piece that is not bytes: four to eight fields, no
  # pixels, and nothing for the server to address by content. So it carries its
  # own id rather than taking one from its filename, and one file may declare
  # several.
  #
  # Three spellings under one extension, told apart by content: TOML for writing
  # by hand, JSON for anything that generates one, org for a game master who
  # already authors there.
  module Character
    # A reference to a token: either a path to a file, or an id to look up.
    Reference = Struct.new(:kind, :target, :name) do
      def path? = kind == :path
    end

    Declared = Struct.new(:fields, :token, :extras) do
      def id = fields['id']
    end

    class Invalid < StandardError
    end

    FIELDS = {
      'ID' => 'id',
      'CLASS' => 'class',
      'PLAYER' => 'player_name',
      'COLOR' => 'color',
      'CHARKEEPER_ID' => 'charkeeper_id'
    }.freeze

    module_function

    def read(path)
      spelling = spelling(path)
      declared = spelling == :org ? from_org(path) : from_data(path, spelling)

      raise Invalid, "#{File.basename(path)} declares no characters" if declared.empty?

      declared
    end

    # A TOML table header: `[characters]` or `[[characters]]` alone on a line.
    # What tells one from a JSON array, which is the other thing a file may
    # open with a bracket.
    TABLE_HEADER = /\A\[\[?\s*[A-Za-z0-9_\-.]+\s*\]\]?\s*\z/
    KEY_VALUE = /\A[\w-]+\s*=/

    # The same sniff .pmmap makes between an OpenRaster and an XCF: the
    # extension says what the file is for, the bytes say which reader.
    #
    # Read past comments and blank lines first. A TOML file is allowed to open
    # with `# the party`, and one that did used to be handed to Emacs and come
    # back with nothing in it; one that opened with `[[characters]]` - the
    # spelling the documentation gives for several characters in a file - was
    # taken for JSON and refused.
    def spelling(path)
      case significant_line(path)
      when TABLE_HEADER, KEY_VALUE then :toml
      when /\A[{\[]/ then :json
      else :org
      end
    end

    # `#+TITLE:` is org's and stays; `# anything else` is a TOML comment.
    def significant_line(path)
      File.read(path, 2048).to_s.scrub.lines.map(&:strip).find do |line|
        !line.empty? && !(line.start_with?('#') && !line.start_with?('#+'))
      end.to_s
    end

    def from_data(path, spelling = spelling(path))
      text = File.read(path).scrub
      parsed = spelling == :json ? JSON.parse(text) : TomlRB.parse(text)
      entries = parsed.is_a?(Array) ? parsed : parsed['characters'] || [parsed]

      entries.map { |entry| declared_from_data(entry) }
    rescue JSON::ParserError, TomlRB::ParseError => e
      raise Invalid, "#{File.basename(path)} is neither TOML nor JSON: #{e.message}"
    end

    # Every level-one headline is a character, and nothing else is. A headline
    # that is not one is a mistake - most likely a typo in the id - and skipping
    # it would turn that into a character that silently never arrives.
    def from_org(path)
      Org.entries(path).select { |entry| entry['level'] == 1 }.map do |entry|
        declared_from_org(entry)
      end
    end

    def declared_from_org(entry)
      properties = entry['properties'].to_h { |property| [property['key'], property] }

      Declared.new(
        org_fields(properties, entry['heading']),
        references(properties['TOKEN']).first,
        references(properties['EXTRA'])
      ).tap { |declared| validate!(declared, entry['heading']) }
    end

    def org_fields(properties, heading)
      named = FIELDS.filter_map { |key, field| [field, properties.dig(key, 'value')] if properties[key] }

      named.to_h.merge('character_name' => heading).compact
    end

    def declared_from_data(entry)
      Declared.new(
        entry.slice(*FIELDS.values, 'character_name').compact,
        reference(entry['token'], entry['token_name']),
        Array(entry['extras']).map { |extra| reference(extra['target'], extra['name']) }
      ).tap { |declared| validate!(declared, entry['character_name']) }
    end

    # Org draws the distinction itself: a `file:` link is a path and a bare one
    # is `fuzzy`, which org means as "a headline somewhere" and this reads as
    # "an entity id".
    def references(property)
      Array(property && property['links']).map do |link|
        kind = link['type'] == 'file' ? :path : :id
        name = link['text'].to_s.empty? ? nil : link['text']

        reference_for(kind, link['path'], name)
      end
    end

    def reference(target, name)
      return nil if target.nil? || target.empty?

      reference_for(Id.of(target) == target ? :id : :path, target, name)
    end

    def reference_for(kind, target, name)
      raise Invalid, "#{target} is not an id" if kind == :id && Id.of(target) != target

      Reference.new(kind, target, name)
    end

    # A character that cannot be put on a board is not one, and a headline whose
    # id is not an id is not a character at all - most likely a typo, and
    # skipping it would turn that into someone who silently never arrives.
    def validate!(declared, named)
      who = named || declared.id || 'a character'

      raise Invalid, "#{who} has no id of the right shape" unless Id.of(declared.id.to_s) == declared.id
      raise Invalid, "#{who} has no token" if declared.token.nil?
    end
  end
end
