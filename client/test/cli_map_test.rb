# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'stringio'

# `map new` and `map upload` through the CLI, which is where they are reached
# from.
#
# These exist because they did not: `made` kept a two-argument signature after
# its callers dropped to one, and `path-mapper map new` raised ArgumentError on
# a machine where someone tried it. Nothing in the suite called either arm.
class CliMapTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir('cli-map')
    @out = StringIO.new
    @err = StringIO.new
    @original = { 'XDG_CONFIG_HOME' => ENV.fetch('XDG_CONFIG_HOME', nil),
                  'XDG_STATE_HOME' => ENV.fetch('XDG_STATE_HOME', nil),
                  'PATH' => ENV.fetch('PATH', '') }

    sandbox
    configure
  end

  def teardown
    @original.each { |key, value| ENV[key] = value }
    FileUtils.remove_entry(@root)
  end

  def test_map_new_makes_a_map_from_the_template
    assert_equal 0, run_cli(%w[map new])
    assert_match(/Map made: .*pm0001-0000000001\.xcf/, @out.string)
    assert_path_exists File.join(@root, 'library', 'maps', 'pm', 'pm0001-0000000001.xcf')
  end

  def test_map_new_takes_a_name
    run_cli(['map', 'new', "crow's keep"])

    assert_path_exists File.join(@root, 'library', 'maps', 'pm', 'pm0001-0000000001-crow-s-keep.xcf')
  end

  # The file exists either way, so a launch that fails is a success with
  # something to say.
  def test_a_gimp_that_will_not_open_does_not_fail_the_command
    assert_equal 0, run_cli(%w[map new])
    assert_includes @out.string, 'GIMP did not open'
  end

  def test_map_new_without_a_template_says_where_it_looked
    FileUtils.rm_rf(File.join(@root, 'library', 'maps'))

    assert_equal 1, run_cli(%w[map new])
    assert_includes @err.string, 'No map template at'
  end

  def test_map_upload_with_nothing_made_says_so
    assert_equal 1, run_cli(%w[map upload])
    assert_includes @err.string, 'No map has been made yet'
  end

  def test_map_upload_whose_map_is_gone_says_so
    run_cli(%w[map new])
    FileUtils.rm_rf(File.join(@root, 'library', 'maps', 'pm'))

    assert_equal 1, run_cli(%w[map upload])
    assert_includes @err.string, 'is gone'
  end

  def test_an_unknown_map_subcommand_is_usage
    assert_equal 2, run_cli(%w[map sideways])
  end

  private

  # Everything the client reads from its environment points inside @root, and
  # an empty bin first on PATH is how GIMP is kept out of it.
  def sandbox
    ENV['XDG_CONFIG_HOME'] = File.join(@root, 'config')
    ENV['XDG_STATE_HOME'] = File.join(@root, 'state')
    ENV['PATH'] = "#{File.join(@root, 'bin')}:#{@original['PATH']}"
    Dir.mkdir(File.join(@root, 'bin'))
  end

  def run_cli(argv)
    PathMapper::CLI.new(@out, @err).run(argv)
  end

  def configure
    FileUtils.mkdir_p(File.join(@root, 'config', 'pathmapper'))
    FileUtils.mkdir_p(File.join(@root, 'library', 'maps'))
    File.write(File.join(@root, 'library', 'maps', 'template.xcf'), 'gimp xcf v011 pretend')
    File.write(File.join(@root, 'config', 'pathmapper', 'config.toml'), <<~TOML)
      server = "http://localhost:1"
      token = "t"
      library = "#{File.join(@root, 'library')}"
    TOML
  end
end
