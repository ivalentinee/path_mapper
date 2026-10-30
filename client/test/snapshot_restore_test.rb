# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'json'
require 'stringio'
require 'zip'

# Restoring a snapshot, which nothing covered until a helper it alone called
# was deleted with the package formats and the whole path raised NoMethodError
# on the first line of its own report.
#
# The point is the sentence as much as the upload: the three steps are what a
# game master sees, and the counts in them are what said something was wrong.
class SnapshotRestoreTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir('snapshot-restore-test')
    @server = FakeServer.new
    @upload = PathMapper::Upload.new(@server, PathMapper::Report.new(StringIO.new, notifying: false),
                                     PathMapper::Silence.new)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_restores_the_assets_the_entities_and_the_state
    path = snapshot(
      entities: [
        { 'kind' => 'map', 'id' => 'mt0001-0000000001', 'file' => '/upload/aaaa1111.ora' },
        { 'kind' => 'token', 'id' => 'tk0001-0000000001', 'image' => '/upload/bbbb2222.png' }
      ],
      state: { 'version' => 4, 'active_surface' => 'mt0001-0000000001' },
      assets: { 'aaaa1111.ora' => 'ora bytes', 'bbbb2222.png' => 'png bytes' }
    )

    @upload.restore(path)

    assert_equal({ 'aaaa1111.ora' => 'ora bytes', 'bbbb2222.png' => 'png bytes' }, @server.assets)
    assert_equal(%w[mt0001-0000000001 tk0001-0000000001], @server.declared.map { |e| e['id'] })
    assert_equal 'mt0001-0000000001', @server.state['active_surface']
  end

  def test_says_what_it_restored
    path = snapshot(
      entities: [{ 'kind' => 'map', 'id' => 'mt0001-0000000001' }, { 'kind' => 'map', 'id' => 'mt0001-0000000002' }],
      state: { 'version' => 4 },
      assets: { 'aaaa1111.ora' => 'x' }
    )

    assert_equal 'Snapshot restored: 2 entities, 1 asset', @upload.restore(path)
  end

  # "entitys" is why this has a helper of its own rather than going through
  # `plural`, and a count of one is the only thing that shows it.
  def test_one_of_each_is_said_in_the_singular
    path = snapshot(
      entities: [{ 'kind' => 'map', 'id' => 'mt0001-0000000001' }],
      state: { 'version' => 4 },
      assets: { 'aaaa1111.ora' => 'x' }
    )

    assert_equal 'Snapshot restored: 1 entity, 1 asset', @upload.restore(path)
  end

  def test_a_snapshot_missing_its_state_is_refused
    path = File.join(@directory, 'broken.pmsnapshot')
    Zip::File.open(path, Zip::File::CREATE) do |zip|
      zip.get_output_stream('entities.json') { |io| io.write('[]') }
    end

    error = assert_raises(PathMapper::Snapshot::Invalid) { @upload.restore(path) }

    assert_includes error.message, 'state.json'
  end

  private

  def snapshot(entities:, state:, assets:)
    path = File.join(@directory, 'session.pmsnapshot')

    Zip::File.open(path, Zip::File::CREATE) do |zip|
      zip.get_output_stream('entities.json') { |io| io.write(JSON.generate(entities)) }
      zip.get_output_stream('state.json') { |io| io.write(JSON.generate(state)) }
      assets.each { |name, bytes| zip.get_output_stream("assets/#{name}") { |io| io.write(bytes) } }
    end

    path
  end
end
