defmodule PathMapper.Game.PlacementNameTest do
  @moduledoc """
  The design properties of "Names for map tokens", exercised as written.

  Four goblins from one declaration are four of the same name. A name on the
  placement is what lets the table's own words - "the crooked-ear one" - be
  written where everyone can see them.
  """
  use PathMapperWeb.ConnCase, async: false

  alias PathMapper.Game
  alias PathMapper.Game.State.Surface.Token, as: GameToken

  setup do
    load_party()
    load_session()
    :ok = select_surface(1)

    # Placements used to arrive with the scene, from `place_tokens`. They are put
    # down here instead, which is the only way a placement happens now.
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000002")
    :ok
  end

  defp placements, do: Game.get_state().surface.tokens
  defp placement(game_id), do: Enum.find(placements(), &(&1.game_id == game_id))
  defp shown(game_id), do: GameToken.displayed_name(placement(game_id))

  # Property 2: a placement with no name of its own shows its declaration's name.
  test "a placement with no name of its own shows the declaration's" do
    Enum.each(placements(), fn placement ->
      assert placement.name == nil
      assert GameToken.displayed_name(placement) == placement.data.name
    end)
  end

  # Property 1: a placement may carry a name of its own, free text and not unique.
  test "a placement may be given a name of its own" do
    [first | _] = Enum.map(placements(), & &1.game_id)

    :ok = Game.run_action([:tokens, first, :set_name], "crooked ear")

    assert shown(first) == "crooked ear"
  end

  test "a name is free text and need not be unique" do
    [a, b | _] = Enum.map(placements(), & &1.game_id)

    :ok = Game.run_action([:tokens, a, :set_name], "guard by the door")
    :ok = Game.run_action([:tokens, b, :set_name], "guard by the door")

    assert shown(a) == "guard by the door"
    assert shown(b) == "guard by the door"
  end

  # Property 3: naming a placement changes no declaration and no other placement.
  test "naming one placement leaves the declaration and its siblings alone" do
    # Both of these are placed from tk0001-0000000001.
    :ok =
      Game.run_action(
        [:tokens, :add],
        {"tk0001-0000000001", %{game_id: "tk0001-0000000001-fallen"}}
      )

    :ok =
      Game.run_action(
        [:tokens, :add],
        {"tk0001-0000000001", %{game_id: "tk0001-0000000001-standing"}}
      )

    fallen = "tk0001-0000000001-fallen"
    standing = "tk0001-0000000001-standing"
    declared = placement(fallen).data.name

    :ok = Game.run_action([:tokens, fallen, :set_name], "crooked ear")

    assert shown(fallen) == "crooked ear"
    assert shown(standing) == declared
    assert placement(fallen).data.name == declared
    assert placement(standing).data.name == declared
  end

  # Property 2 again, from the other side: clearing returns to the declaration.
  test "clearing a placement's name returns it to the declaration's" do
    [first | _] = Enum.map(placements(), & &1.game_id)
    declared = placement(first).data.name

    :ok = Game.run_action([:tokens, first, :set_name], "crooked ear")
    :ok = Game.run_action([:tokens, first, :set_name], nil)

    assert shown(first) == declared
    assert placement(first).name == nil
  end

  test "a blank name is no name rather than a name" do
    [first | _] = Enum.map(placements(), & &1.game_id)
    declared = placement(first).data.name

    :ok = Game.run_action([:tokens, first, :set_name], "   ")

    assert shown(first) == declared
  end

  # Property 6: a placement's name survives a snapshot and its restore.
  test "a placement's name comes back from a snapshot" do
    [first | _] = Enum.map(placements(), & &1.game_id)
    :ok = Game.run_action([:tokens, first, :set_name], "crooked ear")

    {:ok, manifest} = Game.dump_state()
    manifest = Jason.decode!(Jason.encode!(manifest))

    Game.clear()
    load_party()
    load_session()
    :ok = Game.restore_state(manifest)

    assert shown(first) == "crooked ear"
  end
end
