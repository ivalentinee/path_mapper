# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'zlib'

# Text that leaves the client has to be tagged as text.
#
# File bytes are read as bytes, which is right for an image and wrong for
# anything a person wrote. Left as bytes, a string is tagged BINARY, and
# JSON.generate warns on one that holds anything outside ASCII - then raises
# under json 3. It stays invisible until a name carries an accent.
#
# This used to be mostly about a package manifest. The manifests are gone; the
# two places text still arrives from outside are a filename and a PNG's own tEXt
# chunks, and both carry a map or a token's name to the server.
class EncodingTest < Minitest::Test
  KEEP = 'Крепость Чёрного Камня'

  def binary_strings(value, path = '', found = [])
    case value
    when Hash then value.each { |key, inner| binary_strings(inner, "#{path}/#{key}", found) }
    when Array then value.each_with_index { |inner, i| binary_strings(inner, "#{path}[#{i}]", found) }
    when String then found << path if value.encoding == Encoding::BINARY
    end
    found
  end

  def test_a_name_read_off_a_filename_is_text
    name = PathMapper::Id.name_of("mt0001-0000000001-#{KEEP.tr(' ', '-')}.pmmap")

    assert_equal KEEP, name
    assert_equal Encoding::UTF_8, name.encoding
  end

  # The operation that warned.
  def test_a_declaration_can_be_generated_as_json
    declaration = { 'kind' => 'map', 'id' => 'mt0001-0000000001', 'name' => name_from_disk }

    assert_empty binary_strings(declaration)
    assert_equal KEEP, JSON.parse(JSON.generate(declaration))['name']
  end

  def chunk(type, data)
    [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
  end

  # tEXt is latin-1 by specification: 0xE9 is é, and is not valid UTF-8.
  def test_png_text_is_transcoded_from_latin1
    png = PathMapper::Png::SIGNATURE + chunk('tEXt', "Title\0Caf\xE9".b) + chunk('IEND', '')

    found = PathMapper::Png.text(png)

    assert_equal 'Café', found['Title']
    assert_equal Encoding::UTF_8, found['Title'].encoding
  end

  # Plenty of editors write UTF-8 into tEXt anyway. Reading those bytes as latin-1
  # would produce mojibake, so valid UTF-8 is taken at its word.
  def test_png_text_accepts_utf8_in_a_latin1_chunk
    png = PathMapper::Png::SIGNATURE +
          chunk('tEXt', "Title\0Гоблин".b) +
          chunk('IEND', '')

    assert_equal 'Гоблин', PathMapper::Png.text(png)['Title']
  end

  private

  # Through a real file, because a path read off a directory listing is where a
  # BINARY string would come from if one did.
  def name_from_disk
    Dir.mktmpdir do |directory|
      path = File.join(directory, "mt0001-0000000001-#{KEEP.tr(' ', '-')}.pmmap")
      File.binwrite(path, 'bytes')

      PathMapper::Id.name_of(Dir.glob(File.join(directory, '*')).first)
    end
  end
end
