# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'stringio'

# The upload path for a map, both spellings, through the CLI rather than through
# Xcf alone - because what matters is not that the conversion works but that the
# id, the asset and the declaration come out of it right.
class UploadPieceTest < Minitest::Test
  HEADER = "#{PathMapper::Xcf::SIGNATURE}v011\0".freeze
  ORA = "PK\x03\x04and the rest of a zip"

  def setup
    @directory = Dir.mktmpdir('cli-map-test')
    @bin = File.join(@directory, 'bin')
    Dir.mkdir(@bin)
    @original_path = ENV.fetch('PATH', '')
    @server = FakeServer.new
    @out = StringIO.new
  end

  def teardown
    ENV['PATH'] = @original_path
    FileUtils.remove_entry(@directory)
  end

  def test_a_working_file_is_converted_and_declared_as_a_map
    stub_gimp_writing(ORA)

    upload(working_file('mt0001-0000000001-tavern.xcf'))

    assert_equal ORA, @server.assets.values.first
    assert_equal 'map', @server.loaded['kind']
    assert_equal 'mt0001-0000000001', @server.loaded['id']
    assert_equal 'tavern', @server.loaded['name']
  end

  # The asset is addressed by its content and named for what it now is, not for
  # what the author was editing.
  def test_the_asset_is_stored_as_an_ora_whatever_the_file_was_called
    stub_gimp_writing(ORA)

    upload(working_file('mt0001-0000000001-tavern.xcf'))

    assert_match(/\A[0-9a-f]{16}\.ora\z/, @server.assets.keys.first)
  end

  # The retired plug-in exported to a temporary file, which carried no id, and
  # the id check existed to catch what that caused. The id comes off the
  # filename here, and never off the converted file - which has no name.
  def test_the_id_is_read_before_gimp_is_asked_to_do_anything
    stub_gimp("echo 'GIMP SHOULD NOT HAVE RUN' > #{@directory}/ran\nexit 1\n")
    path = working_file('no-id-at-all.xcf')

    error = assert_raises(PathMapper::Kind::Mismatch) { upload(path) }

    assert_includes error.message, 'carries no id'
    refute_path_exists File.join(@directory, 'ran'), 'GIMP was invoked for a file with no id'
  end

  def test_an_openraster_is_uploaded_with_no_gimp_anywhere
    ENV['PATH'] = @bin
    path = File.join(@directory, 'mt0001-0000000002-cave.pmmap')
    File.binwrite(path, fixtures? ? File.binread(fixture('sessions/standard/mt0001-0000000001-scene-1.pmmap')) : ORA)

    upload(path)

    assert_equal 'mt0001-0000000002', @server.loaded['id']
    assert_equal 'cave', @server.loaded['name']
  end

  def test_a_failing_conversion_declares_nothing
    stub_gimp("exit 1\n")

    assert_raises(PathMapper::Xcf::Failed) { upload(working_file('mt0001-0000000003-ruin.xcf')) }

    assert_nil @server.loaded
    assert_empty @server.assets
  end

  # Neither of these existed, and their absence let a helper be deleted out from
  # under them: `plural` went with the package methods and every token upload
  # raised NoMethodError, with the suite green.
  def test_a_token_is_uploaded_and_described_from_its_own_bytes
    skip 'fixtures not available' unless fixtures?

    upload(fixture('sessions/standard/tk0001-0000000001-monster-1.pmtoken'))

    assert_equal(
      { 'kind' => 'token', 'id' => 'tk0001-0000000001', 'name' => 'monster 1',
        'owner' => 'enemy', 'size' => 2 },
      @server.loaded.slice('kind', 'id', 'name', 'owner', 'size')
    )
  end

  def test_a_wallpaper_is_unpacked_and_declared
    skip 'fixtures not available' unless fixtures?

    upload(fixture('sessions/standard/wp0001-0000000001-wallpaper.pmwallpaper'))

    assert_equal 'wallpaper', @server.loaded['kind']
    assert_equal 'wp0001-0000000001', @server.loaded['id']
  end

  private

  def upload(path)
    PathMapper::Upload.new(@server, PathMapper::Report.new(@out, notifying: false), PathMapper::Silence.new).upload(path)
  end

  def working_file(name)
    path = File.join(@directory, name)
    File.binwrite(path, "#{HEADER}rest of the file")
    path
  end

  # Both names, because the client prefers gimp-console and falls back to gimp:
  # a stub for only one would let a real GIMP on this machine answer instead.
  def stub_gimp(body)
    PathMapper::Xcf::BINARIES.each do |name|
      script = File.join(@bin, name)
      File.write(script, "#!/bin/sh\n#{body}")
      File.chmod(0o755, script)
    end
    ENV['PATH'] = "#{@bin}:#{@original_path}"
  end

  def stub_gimp_writing(bytes)
    source = File.join(@directory, 'source.ora')
    File.binwrite(source, bytes)
    sed = %(printf '%s' "$@" | sed -n "s/.*file_new_for_path('\\([^']*\\.ora\\)').*/\\1/p")
    stub_gimp(%(cp #{source} "$(#{sed})"\n))
  end
end
