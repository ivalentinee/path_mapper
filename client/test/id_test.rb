# frozen_string_literal: true

require 'test_helper'

class IdTest < Minitest::Test
  def test_reads_the_id_from_a_filename
    assert_equal 'tk0001-0000000001', PathMapper::Id.of('tk0001-0000000001-goblin.png')
  end

  def test_ignores_leading_directories
    assert_equal 'tg0001-0000000004', PathMapper::Id.of('player-1/tg0001-0000000004-player-1.png')
  end

  def test_works_without_an_extension
    assert_equal 'st0001-0000000002', PathMapper::Id.of('st0001-0000000002-scene')
  end

  def test_is_nil_when_there_is_no_id
    assert_nil PathMapper::Id.of('wallpaper.png')
  end

  def test_is_nil_for_a_non_string
    assert_nil PathMapper::Id.of(nil)
  end
end
