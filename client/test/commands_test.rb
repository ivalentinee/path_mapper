# frozen_string_literal: true

require 'test_helper'
require 'fileutils'

class CommandsTest < Minitest::Test
  def setup
    skip 'fixtures not present' unless fixtures?
    @server = FakeServer.new
  end

  def adventure
    blob = PathMapper::Blob.open(fixture('adventures/tt0001-0000000001-adventure-1.zip'))
    PathMapper::Commands.new(blob, @server).adventure
  end

  def group
    blob = PathMapper::Blob.open(fixture('groups/tg0001-0000000001-group-1.zip'))
    PathMapper::Commands.new(blob, @server).group
  end

  def of_kind(commands, kind)
    commands.select { |c| c['kind'] == kind }
  end

  def test_the_content_name_is_the_first_eight_bytes_of_the_sha256
    assert_equal 'ba7816bf8f01cfea.png', PathMapper::Commands.content_name('abc', 'png')
  end

  def test_declares_the_adventure_with_the_id_from_its_filename
    command = of_kind(adventure, 'adventure').first

    assert_equal 'tt0001-0000000001', command['id']
    assert_equal 'tt0001-0000000001-adventure-1.zip', command['file']
  end

  def test_declares_every_scene
    scenes = of_kind(adventure, 'scene')

    assert_equal 2, scenes.length
    assert_equal([0, 1], scenes.map { |s| s['order'] })
  end

  def test_declares_maps_and_tokens_as_entities_of_their_own
    commands = adventure

    refute_empty of_kind(commands, 'map')
    assert_equal 2, of_kind(commands, 'token').length
  end

  # A scene cannot refer to something the server has not been told about yet.
  def test_declares_a_scene_after_what_it_names
    commands = adventure
    scene = commands.index { |c| c['kind'] == 'scene' }
    map = commands.index { |c| c['kind'] == 'map' }
    token = commands.index { |c| c['kind'] == 'token' }

    assert map < scene
    assert token < scene
  end

  def test_a_scene_names_its_map_and_tokens_by_id
    scene = of_kind(adventure, 'scene').first

    assert_match(/\Amt0001-\d{10}\z/, scene['map_id'])
    assert_equal %w[tk0001-0000000001 tk0001-0000000002], scene['tokens'].map { |t| t['id'] }.sort
  end

  def test_a_token_carries_its_defaults_and_its_stored_image
    token = of_kind(adventure, 'token').first

    assert token['name']
    assert token['owner']
    assert_match %r{\A/upload/[0-9a-f]{16}\.png\z}, token['image']
  end

  def test_declares_a_group_and_its_players_tokens
    commands = group

    assert_equal 1, of_kind(commands, 'group').length
    assert_equal 5, of_kind(commands, 'token').length
  end

  def test_a_player_carries_the_id_of_the_token_it_uses
    player = of_kind(group, 'group').first['players'].first

    assert_equal 'tk0002-0000000004', player['token_id']
  end

  def test_uploads_only_the_assets_the_commands_name
    adventure

    assert_equal 4, @server.assets.size
  end

  # A blob carries source files beside their exports. Sending them would waste the
  # bandwidth and the disk this whole shape exists to save.
  def test_does_not_upload_an_unreferenced_source_file
    blob = PathMapper::Blob.open(fixture('adventures/tt0001-0000000001-adventure-1.zip'))

    assert blob.assets.key?('map.xcf'), 'the fixture should carry an unreferenced source file'

    PathMapper::Commands.new(blob, @server).adventure

    assert_equal 4, @server.assets.size
  end

  def test_refuses_a_blob_whose_name_carries_no_id
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'nameless.pmadventure')
      FileUtils.cp(fixture('adventures/tt0001-0000000001-adventure-1.zip'), path)

      error = assert_raises(PathMapper::Blob::Invalid) do
        PathMapper::Commands.new(PathMapper::Blob.open(path), @server).adventure
      end

      assert_includes error.message, 'carries no id'
    end
  end
end
