# frozen_string_literal: true

require 'test_helper'
require 'zlib'

class TokenTest < Minitest::Test
  def chunk(type, data)
    [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
  end

  def png(**text)
    PathMapper::Png::SIGNATURE +
      text.map { |keyword, value| chunk('tEXt', "#{keyword}\0#{value}") }.join +
      chunk('IEND', '')
  end

  def describe(path, bytes)
    PathMapper::Token.describe(path, bytes)
  end

  def test_takes_its_name_from_the_png
    found = describe('tk0001-0000000042-anything.png', png(Title: 'Goblin Chief'))

    assert_equal 'Goblin Chief', found['name']
  end

  def test_takes_its_size_from_the_png
    assert_equal 3, describe('tk0001-0000000042-ogre.png', png(Size: '3'))['size']
  end

  # The common case: drop a well-named file in and get a usable token.
  def test_falls_back_to_the_filename_for_a_name
    found = describe('tk0001-0000000042-goblin-chief.png', png)

    assert_equal 'goblin chief', found['name']
  end

  def test_falls_back_to_one_cell_for_a_size
    assert_equal 1, describe('tk0001-0000000042-goblin.png', png)['size']
  end

  def test_falls_back_when_the_title_is_blank
    found = describe('tk0001-0000000042-goblin.png', png(Title: '   '))

    assert_equal 'goblin', found['name']
  end

  def test_falls_back_when_the_size_is_not_a_number
    assert_equal 1, describe('tk0001-0000000042-goblin.png', png(Size: 'large'))['size']
  end

  def test_falls_back_when_the_size_is_not_positive
    assert_equal 1, describe('tk0001-0000000042-goblin.png', png(Size: '0'))['size']
  end

  def test_is_owned_by_the_npc_side_unless_a_scene_says_otherwise
    assert_equal 'npc', describe('tk0001-0000000042-goblin.png', png)['owner']
  end
end
