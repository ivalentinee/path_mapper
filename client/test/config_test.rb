# frozen_string_literal: true

require 'test_helper'

class ConfigTest < Minitest::Test
  def test_reads_server_token_and_library
    config = PathMapper::Config.new(
      'server' => 'http://example.test:4000',
      'token' => 'secret',
      'library' => '/tmp/campaigns'
    )

    assert_equal 'http://example.test:4000', config.server
    assert_equal 'secret', config.token
    assert_equal '/tmp/campaigns/snapshots', config.library.snapshots
  end

  # One path is configured and the rest hang off it, so there is one answer to
  # "where did it put that" and one directory to move.
  def test_every_other_path_is_under_the_library
    library = PathMapper::Config.new(
      'server' => 'http://x', 'token' => 't', 'library' => '/tmp/campaigns'
    ).library

    assert_equal '/tmp/campaigns/maps/template.xcf', library.template
    assert_equal '/tmp/campaigns/maps/pm', library.scratch
    assert_equal '/tmp/campaigns/snapshots', library.snapshots
  end

  def test_the_library_defaults_under_xdg_data_home
    config = PathMapper::Config.new('server' => 'http://x', 'token' => 't')

    assert_equal File.join(PathMapper::Config.default_library, 'snapshots'), config.library.snapshots
  end

  # Quietly writing a game master's snapshots somewhere new is the outcome worth
  # code to avoid.
  def test_a_retired_setting_is_reported_with_where_that_thing_went
    config = PathMapper::Config.new(
      { 'server' => 'http://x', 'token' => 't', 'snapshots' => '~/snaps' }, '/x/config.toml'
    )

    assert_includes config.retired_notice, 'snapshots'
    assert_includes config.retired_notice, '<library>/snapshots'
    assert_includes config.retired_notice, '/x/config.toml'
  end

  def test_a_configuration_with_nothing_retired_says_nothing
    assert_nil PathMapper::Config.new('server' => 'http://x', 'token' => 't').retired_notice
  end

  def test_strips_a_trailing_slash_from_the_server
    config = PathMapper::Config.new('server' => 'http://example.test/', 'token' => 't')

    assert_equal 'http://example.test', config.server
  end

  def test_expands_a_tilde_in_the_library
    config = PathMapper::Config.new('server' => 'http://x', 'token' => 't', 'library' => '~/snaps')

    assert_equal File.join(Dir.home, 'snaps'), config.library.maps.sub('/maps', '')
  end

  def test_defaults_the_timeouts
    config = PathMapper::Config.new('server' => 'http://x', 'token' => 't')

    assert_equal 30, config.open_timeout
    assert_equal 300, config.read_timeout
    assert_equal 300, config.write_timeout
  end

  def test_takes_the_timeouts_from_the_file
    config = PathMapper::Config.new(
      'server' => 'http://x', 'token' => 't', 'open_timeout' => 5, 'read_timeout' => 900
    )

    assert_equal 5, config.open_timeout
    assert_equal 900, config.read_timeout
  end

  # Net::HTTP reads a non-positive timeout as "wait for ever", which is the one
  # outcome a client invoked from a file manager must never have.
  def test_ignores_a_timeout_that_would_mean_never_give_up
    config = PathMapper::Config.new(
      'server' => 'http://x', 'token' => 't', 'open_timeout' => 0, 'read_timeout' => -1
    )

    assert_equal 30, config.open_timeout
    assert_equal 300, config.read_timeout
  end

  def test_refuses_a_missing_token
    error = assert_raises(PathMapper::Config::Missing) do
      PathMapper::Config.new({ 'server' => 'http://x' }, '/somewhere/config.toml')
    end

    assert_includes error.message, 'token'
  end

  def test_refuses_an_empty_token
    assert_raises(PathMapper::Config::Missing) do
      PathMapper::Config.new('server' => 'http://x', 'token' => '   ')
    end
  end

  def test_says_what_to_create_when_the_file_is_absent
    error = assert_raises(PathMapper::Config::Missing) do
      PathMapper::Config.load('/nonexistent/pathmapper/config.toml')
    end

    assert_includes error.message, '/nonexistent/pathmapper/config.toml'
    assert_includes error.message, 'server ='
    assert_includes error.message, 'token ='
  end

  def test_honours_xdg_config_home
    original = ENV.fetch('XDG_CONFIG_HOME', nil)
    ENV['XDG_CONFIG_HOME'] = '/xdg'

    assert_equal '/xdg/pathmapper/config.toml', PathMapper::Config.path
  ensure
    ENV['XDG_CONFIG_HOME'] = original
  end

  # The claim the moduledoc makes: an empty environment is still a working one.
  def test_falls_back_to_the_home_directory_with_no_xdg_variable
    with_environment('XDG_CONFIG_HOME' => nil) do
      assert_equal File.join(Dir.home, '.config', 'pathmapper', 'config.toml'), PathMapper::Config.path
    end
  end

  # The XDG specification says an empty variable is an unset one, and an empty
  # variable is exactly what a desktop entry can hand over.
  def test_treats_an_empty_xdg_variable_as_unset
    with_environment('XDG_CONFIG_HOME' => '') do
      assert_equal File.join(Dir.home, '.config', 'pathmapper', 'config.toml'), PathMapper::Config.path
    end
  end

  private

  def with_environment(values)
    original = values.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
