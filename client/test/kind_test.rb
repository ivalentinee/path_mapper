# frozen_string_literal: true

require 'test_helper'

class KindTest < Minitest::Test
  def test_reads_the_kind_from_the_extension
    assert_equal :token, PathMapper::Kind.of('/x/goblin.pmtoken')
    assert_equal :map, PathMapper::Kind.of('/x/cavern.pmmap')
    assert_equal :map, PathMapper::Kind.of('/x/cavern.xcf')
    assert_equal :snapshot, PathMapper::Kind.of('/x/last-night.pmsnapshot')
  end

  def test_ignores_the_case_of_the_extension
    assert_equal :token, PathMapper::Kind.of('/x/Goblin.PMTOKEN')
  end

  # A format that no longer exists reads as one that never did, which is the
  # right answer: .pmadventure and .pmgroup were dropped, and a game master
  # holding an old one is told it is not a PathMapper file rather than that it
  # is a broken one.
  def test_a_retired_package_format_is_simply_unknown
    error = assert_raises(PathMapper::Kind::Unknown) { PathMapper::Kind.of('/x/old.pmadventure') }

    assert_includes error.message, '.pmadventure'
  end

  def test_refuses_an_extension_it_does_not_know
    error = assert_raises(PathMapper::Kind::Unknown) { PathMapper::Kind.of('/x/notes.txt') }

    assert_includes error.message, '.txt'
    assert_includes error.message, '.pmmap'
  end

  def test_refuses_a_name_with_no_extension
    error = assert_raises(PathMapper::Kind::Unknown) { PathMapper::Kind.of('/x/notes') }

    assert_includes error.message, 'no extension'
  end

  # A renamed file lies. The answer is to say so, not to sniff the content in order
  # to decide what the file is.
  def test_refuses_a_file_that_does_not_match_its_extension
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'liar.pmtoken')
      File.binwrite(path, 'this is not a png')

      error = assert_raises(PathMapper::Kind::Mismatch) do
        PathMapper::Kind.validate!(path, :token)
      end

      assert_includes error.message, 'not a PNG'
    end
  end

  # Both spellings of a map, told apart by content rather than by extension -
  # the extension already said "map", and only which converter to use is left.
  def test_accepts_either_spelling_of_a_map
    skip 'fixtures not available' unless fixtures?

    Dir.mktmpdir do |directory|
      working = File.join(directory, 'mt0001-0000000001-keep.xcf')
      File.binwrite(working, "gimp xcf v011\0and then some")

      assert_equal :map, PathMapper::Kind.validate!(working, :map)
      assert_equal :map, PathMapper::Kind.validate!(
        fixture('sessions/standard/mt0001-0000000001-scene-1.pmmap'), :map
      )
    end
  end

  def test_refuses_a_map_that_is_neither
    Dir.mktmpdir do |directory|
      impostor = File.join(directory, 'mt0001-0000000001-keep.xcf')
      File.binwrite(impostor, 'certainly not a map')

      error = assert_raises(PathMapper::Kind::Mismatch) do
        PathMapper::Kind.validate!(impostor, :map)
      end

      assert_includes error.message, 'mt0001-0000000001-keep.xcf'
      # The file is a .xcf. Telling its owner it "is named .pmmap" asserts
      # something false about the name in front of them.
      assert_includes error.message, '.xcf'
      refute_includes error.message, '.pmmap'
    end
  end

  def test_a_pmmap_is_still_refused_in_its_own_name
    Dir.mktmpdir do |directory|
      impostor = File.join(directory, 'mt0001-0000000001-keep.pmmap')
      File.binwrite(impostor, 'certainly not a map')

      error = assert_raises(PathMapper::Kind::Mismatch) do
        PathMapper::Kind.validate!(impostor, :map)
      end

      assert_includes error.message, '.pmmap'
    end
  end
end
