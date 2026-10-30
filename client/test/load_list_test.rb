# frozen_string_literal: true

require 'test_helper'

class LoadListTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_reads_toml
    list = read(<<~TOML)
      load = ["base.pmload"]
      pieces = [
        "mp1001-0000000001", # cavern
        "tk1001-0000000002",
      ]
      game_state = "{\\"surfaces\\":{}}"
    TOML

    assert_equal ['base.pmload'], list['load']
    assert_equal %w[mp1001-0000000001 tk1001-0000000002], list['pieces']
    assert_equal '{"surfaces":{}}', list['game_state']
  end

  # The same file written as JSON, because the server's own dump is JSON and a
  # game master scripting one has no reason to reach for a TOML library.
  def test_reads_json
    list = read('{"pieces": ["mp1001-0000000001"], "game_state": "{}"}')

    assert_equal ['mp1001-0000000001'], list['pieces']
    assert_equal '{}', list['game_state']
  end

  # All three keys are optional, and a file carrying none of them is empty
  # rather than broken - a list being composed has to survive being half
  # written.
  def test_every_key_is_optional
    list = read("# nothing yet\n")

    assert_empty list['load']
    assert_empty list['pieces']
    assert_nil list['game_state']
  end

  def test_refuses_what_is_neither_toml_nor_json
    error = assert_raises(PathMapper::LoadList::Invalid) { read("pieces = [\n") }

    assert_includes error.message, 'neither TOML nor JSON'
  end

  def test_resolves_a_path_against_the_file_holding_it
    FileUtils.mkdir_p(File.join(@dir, 'maps'))
    piece = File.join(@dir, 'maps', 'mp1001-0000000001-cavern.pmmap')
    File.write(piece, 'x')

    from = File.join(@dir, 'session.pmload')

    assert_equal piece, PathMapper::LoadList.resolve('maps/mp1001-0000000001-cavern.pmmap', from, nil)
  end

  def test_a_path_that_is_not_there_resolves_to_nothing
    assert_nil PathMapper::LoadList.resolve('maps/gone.pmmap', File.join(@dir, 'session.pmload'), nil)
  end

  # An id is the library's question, and a list deliberately names no kind:
  # it carries maps, tokens and wallpapers in one array.
  def test_resolves_an_id_in_the_library
    piece = File.join(@dir, 'mp1001-0000000001-cavern.pmmap')
    File.write(piece, 'x')
    library = PathMapper::Library.new(@dir)

    assert_equal piece, PathMapper::LoadList.resolve('mp1001-0000000001', 'ignored', library)
  end

  def test_an_id_with_no_library_resolves_to_nothing
    assert_nil PathMapper::LoadList.resolve('mp1001-0000000001', 'ignored', nil)
  end

  def test_renders_pieces_grouped_by_kind_with_the_state_as_a_string
    groups = {
      'map' => [{ 'id' => 'mp1001-0000000001', 'kind' => 'map', 'name' => 'Cavern' }],
      'token' => [{ 'id' => 'tk1001-0000000002', 'kind' => 'token' }]
    }

    rendered = PathMapper::LoadList.render(groups, { 'surfaces' => {} })

    assert_includes rendered, '  # maps'
    assert_includes rendered, '  "mp1001-0000000001", # Cavern'
    assert_includes rendered, '  # tokens'
    assert_includes rendered, '  "tk1001-0000000002",'
    assert_includes rendered, 'game_state = "{\\"surfaces\\":{}}"'
  end

  # What save writes, read back by the reader - the one property that matters,
  # since the two halves are the only users of the format.
  def test_what_it_renders_it_reads
    groups = { 'map' => [{ 'id' => 'mp1001-0000000001', 'name' => 'Cavern' }] }
    list = read(PathMapper::LoadList.render(groups, { 'surfaces' => {} }))

    assert_equal ['mp1001-0000000001'], list['pieces']
    assert_equal '{"surfaces":{}}', list['game_state']
  end

  # A name with a quote in it would otherwise close the comment's own line and
  # produce TOML that no longer parses.
  def test_a_name_travels_as_a_comment_and_cannot_break_the_file
    groups = { 'map' => [{ 'id' => 'mp1001-0000000001', 'name' => 'The "Deep" Cavern' }] }
    list = read(PathMapper::LoadList.render(groups, {}))

    assert_equal ['mp1001-0000000001'], list['pieces']
  end

  private

  def read(text)
    path = File.join(@dir, 'session.pmload')
    File.write(path, text)

    PathMapper::LoadList.read(path)
  end
end
