# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'json'

# A character read out of each of the three spellings.
#
# The org cases run a stub `emacs` first on PATH, the way the GIMP cases run a
# stub `gimp`: the real Emacs is not available to the suite, and what is being
# tested here is the client's half - which fields it takes, which references it
# makes, and what it refuses.
class CharacterTest < Minitest::Test
  ENTRY = {
    'level' => 1,
    'heading' => 'Valeros',
    'properties' => [
      { 'key' => 'ID', 'value' => 'pg0001-0000000001', 'links' => nil },
      { 'key' => 'CLASS', 'value' => 'Fighter', 'links' => nil },
      { 'key' => 'PLAYER', 'value' => 'Johnny', 'links' => nil },
      { 'key' => 'COLOR', 'value' => '#328546', 'links' => nil },
      { 'key' => 'TOKEN', 'value' => '…',
        'links' => [{ 'type' => 'file', 'path' => 'assets/pg0001-0000000001-valeros.pmtoken',
                      'text' => 'Valeros' }] },
      { 'key' => 'EXTRA', 'value' => '…',
        'links' => [{ 'type' => 'fuzzy', 'path' => 'tk0002-0000000002', 'text' => 'Bloodied' }] }
    ]
  }.freeze

  def setup
    @directory = Dir.mktmpdir('character-test')
    @bin = File.join(@directory, 'bin')
    Dir.mkdir(@bin)
    @original_path = ENV.fetch('PATH', '')
  end

  def teardown
    ENV['PATH'] = @original_path
    FileUtils.remove_entry(@directory)
  end

  def test_reads_a_character_from_org
    character = PathMapper::Character.read(org([ENTRY])).first

    assert_equal(
      { 'id' => 'pg0001-0000000001', 'character_name' => 'Valeros',
        'class' => 'Fighter', 'player_name' => 'Johnny', 'color' => '#328546' },
      character.fields
    )
  end

  # The two kinds of reference, in one character, told apart by org's own link
  # type rather than by anything the client inspects.
  def test_a_file_link_is_a_path_and_a_bare_one_is_an_id
    character = PathMapper::Character.read(org([ENTRY])).first

    assert_predicate character.token, :path?
    assert_equal 'assets/pg0001-0000000001-valeros.pmtoken', character.token.target
    refute_predicate character.extras.first, :path?
    assert_equal 'tk0002-0000000002', character.extras.first.target
  end

  def test_the_link_description_names_the_token
    character = PathMapper::Character.read(org([ENTRY])).first

    assert_equal 'Valeros', character.token.name
    assert_equal 'Bloodied', character.extras.first.name
  end

  # A character that cannot be put on a board is not one.
  def test_refuses_a_character_with_no_token
    without = { 'level' => 1, 'heading' => 'Valeros',
                'properties' => [{ 'key' => 'ID', 'value' => 'pg0001-0000000001', 'links' => nil }] }

    error = assert_raises(PathMapper::Character::Invalid) { PathMapper::Character.read(org([without])) }

    assert_includes error.message, 'no token'
  end

  def test_refuses_a_headline_that_is_not_a_character
    stray = { 'level' => 1, 'heading' => 'Notes',
              'properties' => [{ 'key' => 'ID', 'value' => 'notes', 'links' => nil }] }

    error = assert_raises(PathMapper::Character::Invalid) { PathMapper::Character.read(org([stray])) }

    assert_includes error.message, 'Notes'
    assert_includes error.message, 'no id of the right shape'
  end

  # A binary file renamed .org, and a missing one, both leave Emacs printing
  # "null" and exiting 0 - so nothing found has to be the refusal.
  def test_refuses_a_file_that_yields_no_characters
    error = assert_raises(PathMapper::Character::Invalid) { PathMapper::Character.read(org([])) }

    assert_includes error.message, 'declares no characters'
  end

  def test_says_emacs_is_missing_rather_than_failing_obscurely
    ENV['PATH'] = @bin
    path = File.join(@directory, 'party.pmcharacter')
    File.write(path, "* Valeros\n:PROPERTIES:\n:ID: pg0001-0000000001\n:END:\n")

    error = assert_raises(PathMapper::Org::Unavailable) { PathMapper::Character.read(path) }

    assert_includes error.message, 'Emacs is not installed'
    assert_includes error.message, 'TOML or JSON'
  end

  def test_reads_a_character_from_toml
    character = PathMapper::Character.read(written('valeros.pmcharacter', <<~TOML)).first
      id = "pg0001-0000000001"
      character_name = "Valeros"
      class = "Fighter"
      player_name = "Johnny"
      color = "#328546"
      token = "assets/pg0001-0000000001-valeros.pmtoken"
      token_name = "Valeros"

      [[extras]]
      target = "tk0002-0000000002"
      name = "Bloodied"
    TOML

    assert_equal 'Johnny', character.fields['player_name']
    assert_predicate character.token, :path?
    assert_equal 'tk0002-0000000002', character.extras.first.target
  end

  def test_reads_a_character_from_json
    character = PathMapper::Character.read(written('valeros.pmcharacter', <<~JSON)).first
      { "id": "pg0001-0000000001",
        "character_name": "Valeros",
        "class": "Fighter",
        "player_name": "Johnny",
        "color": "#328546",
        "token": "assets/pg0001-0000000001-valeros.pmtoken",
        "token_name": "Valeros",
        "extras": [{ "target": "tk0002-0000000002", "name": "Bloodied" }] }
    JSON

    assert_equal 'Fighter', character.fields['class']
    assert_equal 'Bloodied', character.extras.first.name
  end

  def test_several_characters_in_one_file
    second = ENTRY.merge('heading' => 'Kyra')
    second = second.merge('properties' => second['properties'].map do |property|
      property['key'] == 'ID' ? property.merge('value' => 'pg0001-0000000002') : property
    end)

    assert_equal 2, PathMapper::Character.read(org([ENTRY, second])).length
  end

  private

  def written(name, body)
    path = File.join(@directory, name)
    File.write(path, body)
    path
  end

  # Stands in for `emacs -Q --batch …`: prints the JSON the real one would.
  def org(entries)
    stub = File.join(@bin, 'emacs')
    File.write(stub, "#!/bin/sh\ncat <<'JSON'\n#{JSON.generate(entries)}\nJSON\n")
    File.chmod(0o755, stub)
    ENV['PATH'] = "#{@bin}:#{@original_path}"

    written('party.pmcharacter', "* Valeros\n:PROPERTIES:\n:ID: pg0001-0000000001\n:END:\n")
  end

  # The extension says what the file is for and the bytes say which reader.
  # Comments and table headers are ordinary TOML, and both used to send the
  # file to the wrong one: a leading comment made it org, which came back
  # empty, and a leading [[characters]] made it JSON, which was refused.
  def test_reads_toml_that_opens_with_a_comment
    declared = read(<<~TOML)
      # the party, as of tonight
      id = "pg0001-0000000001"
      character_name = "Valeros"
      token = "tk0001-0000000001"
    TOML

    assert_equal(['Valeros'], declared.map { |one| one.fields['character_name'] })
  end

  def test_reads_toml_that_opens_with_a_table_header
    declared = read(<<~TOML)
      [[characters]]
      id = "pg0001-0000000001"
      character_name = "Valeros"
      token = "tk0001-0000000001"

      [[characters]]
      id = "pg0001-0000000002"
      character_name = "Kyra"
      token = "tk0001-0000000002"
    TOML

    assert_equal(%w[Valeros Kyra], declared.map { |one| one.fields['character_name'] })
  end

  def test_still_reads_json
    declared = read(<<~JSON)
      { "id": "pg0001-0000000001", "character_name": "Valeros",
        "token": "tk0001-0000000001" }
    JSON

    assert_equal(['Valeros'], declared.map { |one| one.fields['character_name'] })
  end

  # Org keeps `#+` to itself, so stripping TOML comments must not strip it.
  def test_org_metadata_is_not_a_comment
    @sniff_dir ||= Dir.mktmpdir
    path = File.join(@sniff_dir, 'party.pmcharacter')
    File.write(path, "#+TITLE: the party\n\n* Valeros\n")

    assert_equal :org, PathMapper::Character.spelling(path)
  end

  def read(text)
    @sniff_dir ||= Dir.mktmpdir
    path = File.join(@sniff_dir, 'party.pmcharacter')
    File.write(path, text)

    PathMapper::Character.read(path)
  end
end
