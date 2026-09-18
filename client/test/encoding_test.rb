# frozen_string_literal: true

require 'test_helper'
require 'zip'

# Text that leaves the client has to be tagged as text.
#
# Zip entries are read as bytes, which is right for an image and wrong for a
# manifest. Left as bytes, every string the TOML parser returns is tagged BINARY,
# and JSON.generate warns on one that holds anything outside ASCII - then raises
# under json 3. It stays invisible until a name carries an accent.
class EncodingTest < Minitest::Test
  TITLE = 'Гости́ница «Разби́тый меч» — да́нжен'
  SCENE = 'Подва́л'

  def manifest
    <<~TOML
      title = "#{TITLE}"

      [[scenes]]
      id = "st0001-0000000001"
      name = "#{SCENE}"
      type = "battle"
      tokens = [
        { name = "Гобли́н", size = 1, owner = "enemy", image = "tokens/tk0001-0000000001-g.png" }
      ]
    TOML
  end

  def blob(manifest_bytes = manifest)
    path = File.join(Dir.mktmpdir, 'tt0001-0000000001-utf8.zip')

    Zip::File.open(path, Zip::File::CREATE) do |zip|
      zip.get_output_stream('manifest.toml') { |io| io.write(manifest_bytes) }
      zip.get_output_stream('tokens/tk0001-0000000001-g.png') { |io| io.write('not a real png') }
    end

    PathMapper::Blob.open(path)
  end

  def binary_strings(value, path = '', found = [])
    case value
    when Hash then value.each { |key, inner| binary_strings(inner, "#{path}/#{key}", found) }
    when Array then value.each_with_index { |inner, i| binary_strings(inner, "#{path}[#{i}]", found) }
    when String then found << path if value.encoding == Encoding::BINARY
    end
    found
  end

  def test_manifest_strings_are_text_not_bytes
    assert_empty binary_strings(blob.manifest)
  end

  def test_manifest_text_survives_intact
    assert_equal TITLE, blob.manifest['title']
    assert_equal SCENE, blob.manifest['scenes'].first['name']
  end

  # The operation that warned.
  def test_a_manifest_can_be_generated_as_json
    assert_equal TITLE, JSON.parse(JSON.generate(blob.manifest))['title']
  end

  def test_a_manifest_that_is_not_utf8_is_refused
    error = assert_raises(PathMapper::Blob::Invalid) do
      blob("title = \"\xFF\xFE broken\"\n".b).manifest
    end

    assert_includes error.message, 'not valid UTF-8'
  end

  def test_no_command_carries_bytes_where_it_means_text
    commands = PathMapper::Commands.new(blob, FakeServer.new).adventure

    assert_empty binary_strings(commands)
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
end
