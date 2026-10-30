# frozen_string_literal: true

require 'test_helper'

# What the program remembers, which is deliberately not in the file the game
# master writes.
class StateTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir('state-test')
    @path = File.join(@directory, 'nested', 'state.toml')
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_starts_at_nothing_remembered
    state = PathMapper::State.load(@path)

    assert_equal 0, state.counter
    assert_nil state.last_map
  end

  def test_survives_being_written_and_read_back
    PathMapper::State.load(@path).tap do |state|
      state.claim_id
      state.claim_id
      state.remember('/maps/pm/pm0001-0000000002.xcf')
    end

    reread = PathMapper::State.load(@path)

    assert_equal 2, reread.counter
    assert_equal '/maps/pm/pm0001-0000000002.xcf', reread.last_map
  end

  def test_makes_its_own_directory
    PathMapper::State.load(@path).claim_id

    assert_path_exists @path
  end

  # The counter is derivable from the path - the id is in the name - and is kept
  # separately so that losing the file does not rewind the numbering.
  def test_forgetting_the_path_does_not_rewind_the_counter
    PathMapper::State.load(@path).tap { |s| 5.times { s.claim_id } }
    File.write(@path, "counter = 5\n")

    assert_equal 6, PathMapper::State.load(@path).claim_id
  end

  def test_it_is_not_the_configuration
    refute_equal File.dirname(PathMapper::Config.path), File.dirname(PathMapper::State.path)
    assert_includes PathMapper::State.path, 'state'
  end

  def test_an_empty_xdg_state_home_is_an_unset_one
    original = ENV.fetch('XDG_STATE_HOME', nil)
    ENV['XDG_STATE_HOME'] = ''

    assert_equal File.join(Dir.home, '.local', 'state', 'path-mapper', 'state.toml'),
                 PathMapper::State.path
  ensure
    ENV['XDG_STATE_HOME'] = original
  end
end
