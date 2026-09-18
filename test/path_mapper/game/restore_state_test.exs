defmodule PathMapper.Game.RestoreStateTest do
  use ExUnit.Case

  import PathMapperWeb.TestHelpers

  setup do
    PathMapper.Game.clear()
    :ok
  end

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Game.Palette
  alias PathMapper.Game.Restore
  alias PathMapper.Game.State
  alias PathMapper.Groups
  alias PathMapper.Session.Commands

  @adventure_id "tt0001-0000000001"
  @other_adventure_id "tt0001-0000000002"
  @group_id "tg0001-0000000001"

  setup do
    # Start from a known session: a group left loaded by an earlier file would
    # otherwise be recorded in a snapshot taken here as having no group.
    Game.clear()
    on_exit(fn -> Game.clear() end)
    :ok
  end

  defp snapshot_of(adventure_file, group_file) do
    load_adventure(adventure_file)
    if group_file, do: load_group(group_file)
    select_scene(1)
    {:ok, manifest} = Game.dump_state()
    Jason.decode!(Jason.encode!(manifest))
  end

  test "restoring against the adventure the snapshot names succeeds" do
    manifest = snapshot_of("tt0001-0000000001-adventure-1.zip", nil)

    assert :ok = Game.restore_state(manifest)
    assert {:ok, adventure} = Adventures.get_loaded()
    assert adventure.id == @adventure_id
  end

  test "restoring against the group the snapshot names succeeds" do
    manifest = snapshot_of("tt0001-0000000001-adventure-1.zip", "tg0001-0000000001-group-1.zip")

    assert :ok = Game.restore_state(manifest)
    assert {:ok, group} = Groups.get_loaded()
    assert group.id == @group_id
  end

  test "a restored session colours player-owned tokens from the group" do
    manifest = snapshot_of("tt0001-0000000001-adventure-1.zip", "tg0001-0000000001-group-1.zip")
    {:ok, group} = Groups.get_loaded()
    player = List.first(group.players)

    assert :ok = Game.restore_state(manifest)
    assert Palette.resolve(player.id) == player.color
  end

  test "refuses when no adventure is loaded, and says which it wanted" do
    manifest = snapshot_of("tt0001-0000000001-adventure-1.zip", nil)
    Game.clear()

    assert {:error, message} = Game.restore_state(manifest)
    assert message =~ @adventure_id
    assert message =~ "none is loaded"
  end

  test "refuses when a different adventure is loaded, and says which" do
    manifest = snapshot_of("tt0001-0000000001-adventure-1.zip", nil)
    Game.clear()
    load_adventure("tt0001-0000000002-adventure-2.zip")

    assert {:error, message} = Game.restore_state(manifest)
    assert message =~ @adventure_id
    assert message =~ @other_adventure_id
  end

  test "refuses when the group does not match" do
    manifest = snapshot_of("tt0001-0000000001-adventure-1.zip", "tg0001-0000000001-group-1.zip")
    {:ok, group} = Groups.get_loaded()
    :ok = Commands.remove(group.id)

    {:ok, _stored} =
      Commands.put(%PathMapper.Session.Entity{
        id: "tg0001-9999999999",
        kind: "group",
        data: %{group | id: "tg0001-9999999999"}
      })

    assert {:error, message} = Game.restore_state(manifest)
    assert message =~ @group_id
  end

  # A snapshot that names no group references no group, so there is nothing to
  # match and the loaded one is left alone. Whether that is what a game master
  # wants belongs to snapshot-by-reference.
  test "a snapshot naming no group leaves a loaded group alone" do
    manifest = snapshot_of("tt0001-0000000001-adventure-1.zip", nil)
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")

    assert :ok = Game.restore_state(manifest)
    assert {:ok, _still_loaded} = Groups.get_loaded()
  end

  test "adventure tokens placed on the map come back after a restore" do
    manifest = snapshot_of("tt0001-0000000001-adventure-1.zip", nil)
    placed = Enum.map(Game.get_state().scene.tokens, & &1.data.name)
    assert "monster 1" in placed

    assert :ok = Game.restore_state(manifest)

    assert Enum.map(Game.get_state().scene.tokens, & &1.data.name) == placed
  end

  test "player tokens placed on the map come back after a restore" do
    load_adventure("tt0001-0000000001-adventure-1.zip")
    load_group("tg0001-0000000001-group-1.zip")
    select_scene(1)
    Game.run_action([:tokens, :player, :add], "pg0001-0000000001")
    Game.run_action([:tokens, :player, :add_extra], {"pg0001-0000000001", 0})

    placed = Enum.map(Game.get_state().scene.tokens, & &1.data.name)
    assert "Character 1" in placed
    assert "[Character 1] Some marker" in placed

    {:ok, manifest} = Game.dump_state()
    manifest = Jason.decode!(Jason.encode!(manifest))

    assert :ok = Game.restore_state(manifest)

    restored = Game.get_state().scene.tokens
    names = Enum.map(restored, & &1.data.name)
    assert "Character 1" in names
    assert "[Character 1] Some marker" in names

    token = Enum.find(restored, &(&1.data.name == "Character 1"))
    assert token.owner == "pg0001-0000000001"
    assert token.data.image
  end

  test "renaming a character breaks neither their tokens nor their colour" do
    load_adventure("tt0001-0000000001-adventure-1.zip")
    load_group("tg0001-0000000001-group-1.zip")
    select_scene(1)
    Game.run_action([:tokens, :player, :add], "pg0001-0000000001")

    {:ok, manifest} = Game.dump_state()
    manifest = Jason.decode!(Jason.encode!(manifest))

    # The player fixes a typo between save and load, which reaches the server as a
    # replace of the group entity - the same id, new content.
    {:ok, group} = Groups.get_loaded()
    [first | rest] = group.players
    renamed = %{first | character_name: "Character 1 (fixed)"}
    edited = %{group | players: [renamed | rest]}

    {:ok, _stored} =
      Commands.put(%PathMapper.Session.Entity{id: group.id, kind: "group", data: edited})

    # Rebuild from the snapshot against the edited group.
    {:ok, adventure} = Adventures.get_loaded()
    {:ok, snapshot} = Restore.read(manifest)
    {:ok, state} = Restore.build(snapshot.data, adventure)

    tokens = State.scene(state).tokens
    token = Enum.find(tokens, &(&1.owner == "pg0001-0000000001"))

    assert token, "the renamed player's token was dropped"
    assert token.data.name == "Character 1 (fixed)"
    assert Palette.resolve(token.owner) == first.color
  end

  test "a snapshot naming an adventure nobody has loaded is refused, and says which" do
    manifest =
      "tt0001-0000000001-adventure-1.zip"
      |> snapshot_of(nil)
      |> Map.put("adventure_id", "zz9999-9999999999")

    assert {:error, message} = Game.restore_state(manifest)
    assert message =~ "zz9999-9999999999"
  end
end
