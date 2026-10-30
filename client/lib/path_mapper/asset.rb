# frozen_string_literal: true

require 'digest'

module PathMapper
  # An asset's address, which is its bytes.
  #
  # Identity lives in a filename and an address lives in content, which is why
  # the two are read at different moments: the id while the original name still
  # exists, the address once the bytes are in hand. Eight bytes of SHA-256 is
  # enough for a session's worth of images and short enough to read in a URL.
  module Asset
    module_function

    def name(bytes, extension)
      "#{Digest::SHA256.digest(bytes)[0, 8].unpack1('H*')}.#{extension}"
    end

    # Which image these bytes are, by the signature they open with.
    #
    # Read from the content because the name does not say: a .pmwallpaper is
    # the image itself, under an extension that says what it is for rather
    # than what it is. The asset it becomes is served by extension, so one has
    # to be found somewhere.
    SIGNATURES = {
      'png' => "\x89PNG\r\n\x1A\n".b,
      'jpg' => "\xFF\xD8\xFF".b,
      'gif' => 'GIF8'.b
    }.freeze

    def image_extension(bytes)
      return 'webp' if bytes.start_with?('RIFF'.b) && bytes[8, 4] == 'WEBP'

      SIGNATURES.find { |_extension, signature| bytes.start_with?(signature) }&.first
    end
  end
end
