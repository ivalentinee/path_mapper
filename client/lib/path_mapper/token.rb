# frozen_string_literal: true

module PathMapper
  # What a token uploaded on its own is called, and how big it is.
  #
  # A PNG can say both. Where it does not, the name is the descriptive half of the
  # filename and the size is one cell - which is the common case, and is why a game
  # master can drop a well-named file in and get a usable token without editing
  # metadata first.
  module Token
    NAME_KEY = 'Title'
    SIZE_KEY = 'Size'
    DEFAULT_SIZE = 1

    module_function

    def describe(path, bytes)
      text = Png.text(bytes)

      {
        'name' => name(text, path),
        'size' => size(text),
        'owner' => 'npc'
      }
    end

    def name(text, path)
      titled = text[NAME_KEY].to_s.strip
      titled.empty? ? Id.name_of(path) : titled
    end

    # A size that is not a positive whole number is not a size. Falling back beats
    # refusing: the file is still a perfectly good token.
    def size(text)
      value = Integer(text[SIZE_KEY].to_s.strip, 10)
      value.positive? ? value : DEFAULT_SIZE
    rescue ArgumentError, TypeError
      DEFAULT_SIZE
    end
  end
end
