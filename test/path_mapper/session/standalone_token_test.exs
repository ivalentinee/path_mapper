defmodule PathMapper.Session.StandaloneTokenTest do
  @moduledoc """
  A token uploaded on its own reaches the board.

  Uploading a `.pmtoken` declares a token entity that arrived with no package
  around it. There is no roster any more and nothing but the store to read, so
  this is now the ordinary case rather than the exception it once was - which is
  itself worth holding in a test.
  """
  use PathMapperWeb.ConnCase, async: false

  alias PathMapper.Game
  alias PathMapper.Game.Actions.Tokens.Find
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Resolve
  alias PathMapper.Session.Store

  @loose "tu0000-2000000001"

  setup do
    load_party()
    load_session()
    :ok = select_surface(1)

    {:ok, token} = Entity.build("token", declaration())
    {:ok, _} = Store.put(token)
    :ok = Game.reconcile()
    %{characters: Resolve.characters()}
  end

  defp placements, do: Game.get_state().surface.tokens

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

  test "it can be placed on the active scene by its id" do
    before = length(placements())

    :ok = Game.run_action([:tokens, :add], @loose)

    placed = Enum.find(placements(), &(&1.data.id == @loose))

    assert length(placements()) == before + 1
    assert placed.data.name == "Зомби-ходок"
    assert placed.data.owner == "enemy"
  end

  # A character's tokens are placed from their own panels, which know a character
  # goes down once and a marking as often as asked.
  test "a character's tokens are not offered as general tokens", %{characters: characters} do
    character = hd(characters)
    excluded = Find.character_token_ids()

    assert MapSet.member?(excluded, character.token_id)
    assert Enum.all?(character.extra_token_ids, &MapSet.member?(excluded, &1))

    refute MapSet.member?(excluded, @loose), "a standalone token is not a character's"
    refute MapSet.member?(excluded, "tk0001-0000000001"), "nor is one an adventure declared"
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
    load_party()
    load_session()
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

  test "a scene's own roster still overrides what the store says" do
    # tk0001-0000000001 is declared by the scene, so the scene's view of it wins.
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")

    placed = Enum.find(placements(), &(&1.data.id == "tk0001-0000000001"))

    assert placed.data.name == "monster 1"
  end
end
