# frozen_string_literal: true

require 'test_helper'
require 'zlib'

class TokenTest < Minitest::Test
  # Built as bytes: a PNG chunk is binary, and a comment may be any UTF-8.
  def chunk(type, data)
    data = data.b
    type = type.b
    [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
  end

  # A PNG carrying one comment, which is where every setting now lives.
  def png(comment = nil)
    PathMapper::Png::SIGNATURE +
      (comment ? chunk('tEXt', "Comment\0#{comment}") : ''.b) +
      chunk('IEND', '')
  end

  def describe(path, bytes)
    PathMapper::Token.describe(path, bytes)
  end

  def test_reads_every_setting_from_one_comment
    found = describe('tk0001-0000000042-anything.png',
                     png('name: Goblin Chief | size: 3 | owner: enemy'))

    assert_equal 'Goblin Chief', found['name']
    assert_equal 3, found['size']
    assert_equal 'enemy', found['owner']
  end

  def test_settings_may_come_in_any_order
    found = describe('tk0001-0000000042-anything.png',
                     png('owner: enemy | size: 2 | name: Ogre'))

    assert_equal({ 'name' => 'Ogre', 'size' => 2, 'owner' => 'enemy' }, found)
  end

  # Typed into an export dialog by a person, so spacing and case are theirs.
  def test_tolerates_spacing_and_case_around_keys
    found = describe('tk0001-0000000042-anything.png',
                     png('  Name :Goblin Chief|SIZE: 2  |Owner:  ENEMY '))

    assert_equal 'Goblin Chief', found['name']
    assert_equal 2, found['size']
    assert_equal 'enemy', found['owner']
  end

  def test_keeps_a_name_that_contains_spaces_and_non_latin_text
    found = describe('tk0001-0000000042-x.png', png('name: Зомби-ходок | size: 1'))

    assert_equal 'Зомби-ходок', found['name']
  end

  # The common case: drop a well-named file in and get a usable token.
  def test_a_file_with_no_comment_is_still_a_token
    found = describe('tk0001-0000000042-goblin-chief.png', png)

    assert_equal({ 'name' => 'goblin chief', 'size' => 1, 'owner' => 'npc' }, found)
  end

  def test_each_setting_is_optional_on_its_own
    found = describe('tk0001-0000000042-goblin.png', png('size: 4'))

    assert_equal 'goblin', found['name']
    assert_equal 4, found['size']
    assert_equal 'npc', found['owner']
  end

  def test_a_comment_that_is_prose_yields_no_settings
    found = describe('tk0001-0000000042-goblin.png', png('Exported from GIMP 3.2'))

    assert_equal({ 'name' => 'goblin', 'size' => 1, 'owner' => 'npc' }, found)
  end

  def test_an_unknown_setting_is_ignored_rather_than_refused
    found = describe('tk0001-0000000042-goblin.png', png('name: Ogre | colour: green'))

    assert_equal 'Ogre', found['name']
    assert_equal 1, found['size']
  end

  def test_falls_back_when_a_name_is_blank
    assert_equal 'goblin', describe('tk0001-0000000042-goblin.png', png('name:   '))['name']
  end

  def test_falls_back_when_a_size_is_not_a_positive_whole_number
    ['size: large', 'size: 0', 'size: -2', 'size: 1.5'].each do |comment|
      assert_equal 1, describe('tk0001-0000000042-goblin.png', png(comment))['size'],
                   "expected #{comment.inspect} to fall back to one cell"
    end
  end

  # The file the format was designed against.
  def test_reads_the_sample_token
    path = '/app/help/tu0000-2000000001-zombie-shambler.png'
    skip 'sample not present' unless File.exist?(path)

    assert_equal({ 'name' => 'Зомби-ходок', 'size' => 1, 'owner' => 'enemy' },
                 describe(path, File.binread(path)))
  end
end
