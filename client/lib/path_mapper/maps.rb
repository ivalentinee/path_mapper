# frozen_string_literal: true

require 'fileutils'

module PathMapper
  # A map made while the game is running.
  #
  # The players go somewhere nobody prepared and the game master draws it while
  # they talk. Copying a template by hand, inventing an id, renaming the file and
  # then finding its path is the interruption this removes; the same operations
  # between sessions are not an interruption, which is why nothing here replaces
  # the ordinary way a map is authored.
  module Maps
    # "pm" for path-mapper, 0001 as the reserved series for maps. A pm0001 map is
    # one the client issued an id for because nobody had time to choose one; the
    # game master's own series is what a map that is kept gets called, and
    # renaming a scratch map into it is the normal end of its life.
    SERIES = 'pm0001'

    module_function

    def create(library, state, name = nil)
      template = library.template!
      path = File.join(library.scratch!, filename(state.claim_id, name))

      FileUtils.cp(template, path)
      state.remember(path)
    end

    # Ten digits, like every other entity id. With no name the descriptive half
    # is simply absent rather than filled with a placeholder, because the id
    # already says this is a map and a word like "pmmap" would only repeat it.
    def filename(counter, name)
      slug = slug(name)
      base = format('%<series>s-%<counter>010d', series: SERIES, counter: counter)

      slug.empty? ? "#{base}.xcf" : "#{base}-#{slug}.xcf"
    end

    def slug(name)
      name.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
    end
  end
end
