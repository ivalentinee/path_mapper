# frozen_string_literal: true

require 'test_helper'
require 'zlib'

class PngTest < Minitest::Test
  def chunk(type, data)
    [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
  end

  def png(*chunks)
    PathMapper::Png::SIGNATURE + chunks.join + chunk('IEND', '')
  end

  def text_chunk(keyword, value)
    chunk('tEXt', "#{keyword}\0#{value}")
  end

  def compressed_chunk(keyword, value)
    chunk('zTXt', "#{keyword}\0\0#{Zlib::Deflate.deflate(value)}")
  end

  def international_chunk(keyword, value, compressed: false)
    body = compressed ? Zlib::Deflate.deflate(value) : value
    chunk('iTXt', "#{keyword}\0#{compressed ? 1.chr : 0.chr}\0en\0#{keyword}\0#{body}")
  end

  def test_reads_a_plain_text_chunk
    assert_equal({ 'Title' => 'Goblin Chief' },
                 PathMapper::Png.text(png(text_chunk('Title', 'Goblin Chief'))))
  end

  def test_reads_a_compressed_text_chunk
    assert_equal 'Goblin Chief',
                 PathMapper::Png.text(png(compressed_chunk('Title', 'Goblin Chief')))['Title']
  end

  def test_reads_an_international_text_chunk
    assert_equal 'Gobelin Chef',
                 PathMapper::Png.text(png(international_chunk('Title', 'Gobelin Chef')))['Title']
  end

  def test_reads_a_compressed_international_text_chunk
    found = PathMapper::Png.text(png(international_chunk('Title', 'Gobelin Chef', compressed: true)))

    assert_equal 'Gobelin Chef', found['Title']
  end

  def test_reads_several_chunks
    found = PathMapper::Png.text(png(text_chunk('Title', 'Ogre'), text_chunk('Size', '3')))

    assert_equal({ 'Title' => 'Ogre', 'Size' => '3' }, found)
  end

  def test_skips_chunks_it_does_not_understand
    found = PathMapper::Png.text(png(chunk('IHDR', 'x' * 13), text_chunk('Title', 'Ogre')))

    assert_equal({ 'Title' => 'Ogre' }, found)
  end

  # A token that cannot be read is still a token: there is a filename to fall back
  # on, and a malformed chunk is not worth failing an upload over.
  def test_is_empty_for_something_that_is_not_a_png
    assert_empty PathMapper::Png.text('this is not a png at all')
  end

  def test_is_empty_for_a_truncated_file
    assert_empty PathMapper::Png.text("#{PathMapper::Png::SIGNATURE}\x00\x00")
  end

  def test_survives_a_corrupt_compressed_chunk
    corrupt = chunk('zTXt', "Title\0\0not actually deflated")

    assert_empty PathMapper::Png.text(png(corrupt))
  end

  def test_is_empty_for_a_non_string
    assert_empty PathMapper::Png.text(nil)
  end
end
