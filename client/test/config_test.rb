# frozen_string_literal: true

require 'test_helper'

class ConfigTest < Minitest::Test
  def test_reads_server_token_and_snapshots
    config = PathMapper::Config.new(
      'server' => 'http://example.test:4000',
      'token' => 'secret',
      'snapshots' => '/tmp/snaps'
    )

    assert_equal 'http://example.test:4000', config.server
    assert_equal 'secret', config.token
    assert_equal '/tmp/snaps', config.snapshots
  end

  def test_strips_a_trailing_slash_from_the_server
    config = PathMapper::Config.new('server' => 'http://example.test/', 'token' => 't')

    assert_equal 'http://example.test', config.server
  end

  def test_expands_a_tilde_in_the_snapshot_directory
    config = PathMapper::Config.new('server' => 'http://x', 'token' => 't', 'snapshots' => '~/snaps')

    assert_equal File.join(Dir.home, 'snaps'), config.snapshots
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
end
