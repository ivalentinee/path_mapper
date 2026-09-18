# frozen_string_literal: true

module PathMapper
  # The id a filename carries.
  #
  # Identity lives in the name; an asset's address is derived from its bytes. Once
  # the server stores an asset under its content name the original name is gone, so
  # the client reads the id while it still can and sends it alongside.
  module Id
    PATTERN = /\A([a-z]{2}\d{4}-\d{10})-(.+?)(\.[A-Za-z0-9]+)?\z/

    module_function

    def of(filename)
      parse(filename)&.first
    end

    # The descriptive half of a name, which is what a token is called when nothing
    # else says otherwise.
    def name_of(filename)
      parse(filename)&.last&.tr('-_', '  ')
    end

    def parse(filename)
      return nil unless filename.is_a?(String)

      match = PATTERN.match(File.basename(filename))
      match && [match[1], match[2]]
    end
  end
end
