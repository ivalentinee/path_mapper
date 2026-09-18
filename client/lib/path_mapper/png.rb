# frozen_string_literal: true

require 'zlib'

module PathMapper
  # The text a PNG carries about itself.
  #
  # PNG has no EXIF in the usual sense; it keeps text in `tEXt`, `zTXt` and `iTXt`
  # chunks, which is where an image editor puts a title. Reading them is a few
  # lines and saves a gem.
  #
  # Nothing here trusts the file. A token that is not a PNG, or is truncated, or
  # carries a chunk this does not understand, yields what could be read and no
  # exception - the caller has a filename to fall back on, and a malformed chunk is
  # not worth failing an upload over.
  module Png
    SIGNATURE = "\x89PNG\r\n\x1A\n".b
    HEADER = 8

    module_function

    # Keyword => text, for every text chunk the file carries.
    def text(bytes)
      return {} unless bytes.is_a?(String) && bytes.b.start_with?(SIGNATURE)

      chunks(bytes.b).each_with_object({}) do |(type, data), found|
        keyword, value = decode(type, data)
        found[keyword] = value if keyword && value && !found.key?(keyword)
      end
    end

    def chunks(bytes)
      offset = HEADER
      found = []

      while offset + HEADER <= bytes.bytesize
        length = bytes.byteslice(offset, 4).unpack1('N')
        type = bytes.byteslice(offset + 4, 4)
        break if length.nil? || type.nil? || type == 'IEND'

        found << [type, bytes.byteslice(offset + HEADER, length).to_s]
        offset += HEADER + length + 4
      end

      found
    end

    def decode(type, data)
      case type
      when 'tEXt' then split_latin1(data)
      when 'zTXt' then decode_ztxt(data)
      when 'iTXt' then decode_itxt(data)
      end
    end

    # tEXt and zTXt are latin-1 by specification, so both halves are transcoded
    # rather than merely relabelled. A text chunk that stayed tagged BINARY would
    # reach JSON.generate as bytes and warn there instead of failing here.
    def split_latin1(data)
      keyword, text = data.split("\0", 2)
      return nil if keyword.nil? || text.nil?

      [latin1(keyword), latin1(text)]
    end

    # tEXt and zTXt are latin-1 by specification, and plenty of editors write UTF-8
    # into them regardless. Reading valid UTF-8 as latin-1 turns "Гоблин" into
    # mojibake, so UTF-8 wins where the bytes are valid UTF-8 - which latin-1 text
    # carrying accents almost never is, since those bytes are not legal UTF-8
    # sequences. Pure ASCII reads the same either way.
    def latin1(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      return text if text.valid_encoding?

      bytes.dup.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
    end

    def decode_ztxt(data)
      keyword, rest = data.split("\0", 2)
      return nil if keyword.nil? || rest.nil? || rest.empty?

      [latin1(keyword), inflate(rest.byteslice(1..).to_s)]
    rescue Zlib::Error
      nil
    end

    # keyword \0 compressed(1) method(1) language \0 translated \0 text
    def decode_itxt(data)
      keyword, rest = data.split("\0", 2)
      return nil if keyword.nil? || rest.nil? || rest.bytesize < 2

      body = itxt_body(rest)
      return nil unless body

      [keyword, rest.getbyte(0) == 1 ? inflate(body) : body.force_encoding(Encoding::UTF_8)]
    rescue Zlib::Error
      nil
    end

    # Past the compression bytes sit two \0-terminated fields, the language and the
    # translated keyword, and the text is whatever follows them.
    def itxt_body(rest)
      _language, remainder = rest.byteslice(2..).to_s.split("\0", 2)
      return nil unless remainder

      _translated, body = remainder.split("\0", 2)
      body
    end

    def inflate(body)
      Zlib::Inflate.inflate(body).force_encoding(Encoding::UTF_8)
    end
  end
end
