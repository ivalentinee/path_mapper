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
  end
end
