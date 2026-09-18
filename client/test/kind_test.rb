# frozen_string_literal: true

require 'test_helper'

class KindTest < Minitest::Test
  def test_reads_the_kind_from_the_extension
    assert_equal :adventure, PathMapper::Kind.of('/x/the-train.pmadventure')
    assert_equal :group, PathMapper::Kind.of('/x/divers.pmgroup')
    assert_equal :token, PathMapper::Kind.of('/x/goblin.pmtoken')
    assert_equal :map, PathMapper::Kind.of('/x/cavern.pmmap')
    assert_equal :snapshot, PathMapper::Kind.of('/x/last-night.pmsnapshot')
  end

  def test_ignores_the_case_of_the_extension
    assert_equal :token, PathMapper::Kind.of('/x/Goblin.PMTOKEN')
  end

  def test_refuses_an_extension_it_does_not_know
    error = assert_raises(PathMapper::Kind::Unknown) { PathMapper::Kind.of('/x/notes.txt') }

    assert_includes error.message, '.txt'
    assert_includes error.message, '.pmadventure'
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

  def test_refuses_an_adventure_that_is_not_an_archive
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'liar.pmadventure')
      File.binwrite(path, 'nope')

      assert_raises(PathMapper::Kind::Mismatch) { PathMapper::Kind.validate!(path, :adventure) }
    end
  end

  def test_accepts_a_real_adventure
    skip 'fixtures not present' unless fixtures?

    path = fixture('adventures/tt0001-0000000001-adventure-1.zip')

    assert_equal :adventure, PathMapper::Kind.validate!(path, :adventure)
  end

  def test_refuses_an_archive_without_a_manifest
    skip 'fixtures not present' unless fixtures?

    error = assert_raises(PathMapper::Kind::Mismatch) do
      PathMapper::Kind.validate!(fixture('adventures/unpacked/map.ora'), :adventure)
    end

    assert_includes error.message, 'manifest.toml'
  end
end
