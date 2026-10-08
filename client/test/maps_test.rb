# frozen_string_literal: true

require 'test_helper'
require 'fileutils'

# Making a map during play: the template copied, the id issued, and the two
# facts the client has to remember afterwards.
class MapsTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir('library-test')
    @library = PathMapper::Library.new(@root)
    @state_path = File.join(@root, 'state.toml')
    FileUtils.mkdir_p(@library.maps)
    File.write(@library.template, 'gimp xcf v011 pretend template')
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_copies_the_template_into_the_scratch_directory
    path = PathMapper::Maps.create(@library, state)

    assert_equal File.join(@root, 'maps', 'pm'), File.dirname(path)
    assert_equal File.read(@library.template), File.read(path)
  end

  def test_the_first_map_is_numbered_one
    assert_equal 'pm0001-0000000001.xcf', File.basename(PathMapper::Maps.create(@library, state))
  end

  def test_a_name_becomes_the_descriptive_half
    path = PathMapper::Maps.create(@library, state, "Crow's Keep")

    assert_equal 'pm0001-0000000001-crow-s-keep.xcf', File.basename(path)
  end

  # The id is what the server knows a surface by, so two maps made in one
  # session must not collide.
  def test_each_map_takes_the_next_id
    kept = state
    names = 3.times.map { File.basename(PathMapper::Maps.create(@library, kept)) }

    assert_equal %w[pm0001-0000000001.xcf pm0001-0000000002.xcf pm0001-0000000003.xcf], names
  end

  # Scratch maps are meant to be renamed away or deleted after a session, so
  # their absence must not restart the numbering.
  def test_the_counter_survives_the_files_it_named
    PathMapper::Maps.create(@library, state)
    FileUtils.rm_rf(@library.scratch)

    assert_equal 'pm0001-0000000002.xcf', File.basename(PathMapper::Maps.create(@library, state))
  end

  def test_the_map_just_made_is_the_one_remembered
    path = PathMapper::Maps.create(@library, state)

    assert_equal path, state.last_map
  end

  # The template is the feature; without one there is nothing to fall back to
  # that would be a map rather than an empty image.
  def test_refuses_without_a_template_and_says_where_it_looked
    File.delete(@library.template)

    error = assert_raises(PathMapper::Library::NoTemplate) { PathMapper::Maps.create(@library, state) }

    assert_includes error.message, @library.template
  end

  def test_makes_the_scratch_directory_if_it_is_not_there
    refute_path_exists @library.scratch

    PathMapper::Maps.create(@library, state)

    assert_path_exists @library.scratch
  end

  # An id is claimed before the file it names exists, so a copy that fails
  # burns one rather than letting the next map reuse it.
  def test_a_failed_copy_does_not_free_the_id
    kept = state
    FileUtils.mkdir_p(@library.scratch)
    FileUtils.chmod(0o500, @library.scratch)
    assert_raises(SystemCallError) { PathMapper::Maps.create(@library, kept) }
    FileUtils.chmod(0o700, @library.scratch)

    assert_equal 'pm0001-0000000002.xcf', File.basename(PathMapper::Maps.create(@library, kept))
  end

  private

  def state
    PathMapper::State.load(@state_path)
  end
end
