# frozen_string_literal: true

module PathMapper
  # The directory where the game master keeps their own files.
  #
  # Pointed at, never managed: the client reads a template out of it and writes
  # new maps and snapshots into it, and does nothing else there. No index, no
  # catalogue, no tidying up.
  #
  # It is the only path a game master configures. Everything the client reads or
  # writes that was not handed to it on the command line is under here, so there
  # is one answer to "where did it put that" and one directory to move.
  class Library
    # Named for what it is rather than what made it: pm0001 is the series the
    # client issues ids in, and these are the maps carrying them.
    SCRATCH = 'pm'

    class NoTemplate < StandardError
    end

    def initialize(root)
      @root = root
    end

    def maps
      File.join(@root, 'maps')
    end

    def template
      File.join(maps, 'template.xcf')
    end

    def scratch
      File.join(maps, SCRATCH)
    end

    def snapshots
      File.join(@root, 'snapshots')
    end

    # The path, or a refusal naming it. A game master who has pointed `library`
    # at their own campaign directory has no template there, and being told the
    # feature is unavailable without being told where it looked reads as the
    # feature being broken.
    def template!
      return template if File.file?(template)

      raise NoTemplate, "No map template at #{template}. Put one there, or point " \
                        '`library` in the configuration at a directory that has one.'
    end

    def scratch!
      FileUtils.mkdir_p(scratch)
      scratch
    end

    def snapshots!
      FileUtils.mkdir_p(snapshots)
      snapshots
    end

    # A reference that is an id, resolved against what the game master keeps.
    #
    # A kind narrows it where the reference knows one, and has to: an author
    # keeps working files beside their exports, a token's .xcf artwork carries
    # the token's id, and a .xcf otherwise means a map, so matching on the id
    # alone would convert a portrait and declare it a playable surface.
    #
    # A load list knows no kind, deliberately - it names a piece and lets the
    # file say what it is - so nil means any piece, and the extension found
    # answers the question the reference did not ask.
    def find(id, kind = nil)
      extensions = Kind::BY_EXTENSION.select { |_extension, named| kind.nil? || named == kind }.keys

      Dir.glob(File.join(@root, '**', "*#{id}*")).find do |path|
        File.file?(path) && Id.of(path) == id && extensions.include?(File.extname(path).downcase)
      end
    end
  end
end
