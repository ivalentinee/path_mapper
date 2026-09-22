defmodule PathMapper.Session.StandaloneTokenTest do
  @moduledoc """
  A token uploaded on its own reaches the board.

  Uploading a `.pmtoken` declares a token entity that no scene names. Both roster
  sources read from scenes - the active scene's own list, and the union of every
  scene's list - so such a token was in the store and reachable from nowhere:
  absent from the panel, and unplaceable even by id.
  """
  use PathMapperWeb.ConnCase, async: false

  alias PathMapper.Adventures
  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Resolve
  alias PathMapper.Session.Store

  @loose "tu0000-2000000001"

  setup do
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    :ok = select_scene(1)

    {:ok, token} = Entity.build("token", declaration())
    {:ok, _} = Store.put(token)
    :ok = Game.reconcile()
    :ok
  end

  defp placements, do: Game.get_state().scene.tokens

  defp declaration do
    %{
      "id" => @loose,
      "name" => "Зомби-ходок",
      "owner" => "enemy",
      "size" => 1,
      "image" => "/upload/4249b4f11c77787c.png"
    }
  end

  test "the session's token library holds it alongside the declared ones" do
    ids = Enum.map(Resolve.tokens(), & &1.id)

    assert @loose in ids
    assert "tk0001-0000000001" in ids, "declared tokens are still listed"
  end

  test "no scene declares it, which is why the old roster missed it" do
    {:ok, adventure} = Adventures.get_loaded()

    refute Enum.any?(Adventure.all_tokens(adventure), &(&1.id == @loose))
  end

  test "it can be placed on the active scene by its id" do
    before = length(placements())

    :ok = Game.run_action([:tokens, :add], @loose)

    placed = Enum.find(placements(), &(&1.data.id == @loose))

    assert length(placements()) == before + 1
    assert placed.data.name == "Зомби-ходок"
    assert placed.data.owner == "enemy"
  end

  # Players' tokens are placed from their own panels, which know a character goes
  # down once and a marking as often as asked.
  test "the group's player tokens are not offered as general tokens" do
    {:ok, group} = Groups.get_loaded()
    player = hd(group.players)
    excluded = Groups.player_token_ids()

    assert MapSet.member?(excluded, player.token_id)
    assert Enum.all?(player.extra_tokens, &MapSet.member?(excluded, &1.id))

    refute MapSet.member?(excluded, @loose), "a standalone token is not a player's"
    refute MapSet.member?(excluded, "tk0001-0000000001"), "nor is a scene's own"
  end

  # A placement of it must survive a snapshot like any other. Restore resolved a
  # placement's token through scene, group and adventure - never the store - so a
  # standalone token's placement was silently dropped on the way back in.
  test "a placement of it comes back from a snapshot" do
    :ok = Game.run_action([:tokens, :add], @loose)
    placed = Enum.find(placements(), &(&1.data.id == @loose))
    assert placed, "precondition: it was placed"

    {:ok, manifest} = Game.dump_state()
    manifest = Jason.decode!(Jason.encode!(manifest))

    Game.clear()
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    {:ok, token} = Entity.build("token", declaration())
    {:ok, _} = Store.put(token)
    :ok = Game.reconcile()

    :ok = Game.restore_state(manifest)

    restored = Enum.find(placements(), &(&1.data.id == @loose))

    assert restored, "the placement came back"
    assert restored.game_id == placed.game_id
    assert restored.data.name == "Зомби-ходок"
  end

  # An authored entry may name any token the session holds, not only the ones the
  # scene lists. An id naming nothing still places nothing.
  test "a place_tokens entry may name it without the scene declaring it" do
    {:ok, scene} =
      Entity.build("scene", %{
        "id" => "st0001-0000000099",
        "name" => "Loose",
        "type" => "battle",
        "order" => 9,
        "tokens" => [],
        "place_tokens" => [
          %{"game_id" => "#{@loose}-here", "x" => 2, "y" => 2},
          %{"game_id" => "tk9999-0000000000-nobody", "x" => 3, "y" => 3}
        ]
      })

    {:ok, _} = Store.put(scene)
    :ok = Game.reconcile()
    :ok = Game.run_action([:scene, :select], "st0001-0000000099")

    assert Enum.map(placements(), & &1.game_id) == ["#{@loose}-here"]
    assert hd(placements()).data.name == "Зомби-ходок"
  end

  test "a scene's own roster still overrides what the store says" do
    # tk0001-0000000001 is declared by the scene, so the scene's view of it wins.
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")

    placed = Enum.find(placements(), &(&1.data.id == "tk0001-0000000001"))

    assert placed.data.name == "monster 1"
  end
end
