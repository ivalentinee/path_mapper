# frozen_string_literal: true

module PathMapper
  # What a token uploaded on its own is called, how big it is, and whose it is.
  #
  # A PNG says so in its `Comment`: a `|`-separated list of `key: value` settings.
  #
  #   name: Зомби-ходок | size: 1 | owner: enemy
  #
  # One property rather than one per setting, because one is what an image editor
  # offers on the way out. GIMP puts a comment field in its export dialog; giving
  # each setting its own PNG key meant a trip through the metadata editor, and
  # ImageMagick will not write a `Size` key at all.
  #
  # Nothing here is required. A well-named file with no comment is a perfectly good
  # token, which is why every setting has an answer for when it is missing.
  module Token
    COMMENT_KEY = 'Comment'
    SEPARATOR = '|'
    DEFAULT_SIZE = 1
    DEFAULT_OWNER = 'npc'

    module_function

    def describe(path, bytes)
      settings = settings(Png.text(bytes))

      {
        'name' => name(settings, path),
        'size' => size(settings),
        'owner' => owner(settings)
      }
    end

    # Keys are matched without case or surrounding space, because a person typed
    # them into a dialog. A value keeps its own spacing, since a name may contain
    # any of it. Anything unrecognised is left alone rather than refused - a
    # comment that is prose rather than settings simply yields none.
    def settings(text)
      text[COMMENT_KEY]
        .to_s
        .split(SEPARATOR)
        .filter_map { |part| setting(part) }
        .to_h
    end

    def setting(part)
      key, value = part.split(':', 2)
      return nil if value.nil?

      key = key.strip.downcase
      return nil if key.empty?

      [key, value.strip]
    end

    def name(settings, path)
      given = settings['name'].to_s
      given.empty? ? Id.name_of(path) : given
    end

    # A size that is not a positive whole number is not a size. Falling back beats
    # refusing: the file is still a perfectly good token.
    def size(settings)
      value = Integer(settings['size'].to_s.strip, 10)
      value.positive? ? value : DEFAULT_SIZE
    rescue ArgumentError, TypeError
      DEFAULT_SIZE
    end

    # Left as written apart from case; which owners a session accepts is the
    # server's to say, and it refuses one it does not know.
    def owner(settings)
      given = settings['owner'].to_s.strip.downcase
      given.empty? ? DEFAULT_OWNER : given
    end
  end
end
