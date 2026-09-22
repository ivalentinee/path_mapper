defmodule PathMapper.Game.PlacementNameTest do
  @moduledoc """
  The design properties of "Names for map tokens", exercised as written.

  Four goblins from one declaration are four of the same name. A name on the
  placement is what lets the table's own words - "the crooked-ear one" - be
  written where everyone can see them.
  """
  use PathMapperWeb.ConnCase, async: false

  alias PathMapper.Game
  alias PathMapper.Game.State.Scene.Token, as: GameToken
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store

  setup do
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    :ok = select_scene(1)
    :ok
  end

  defp placements, do: Game.get_state().scene.tokens
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
    # Both of these were placed from tk0001-0000000001.
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
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    :ok = Game.restore_state(manifest)

    assert shown(first) == "crooked ear"
    assert placement("tk0001-0000000001-standing").name == nil
  end

  # The copy always states a name, resolved, so the converter reading it never
  # needs the token roster to know what an entry is about.
  test "the place_tokens copy states a name for every placement" do
    [first, second | _] = Enum.map(placements(), & &1.game_id)
    :ok = Game.run_action([:tokens, first, :set_name], "crooked ear")

    lines = String.split(GameToken.to_place_records(placements(), 10), "\n")
    named = Enum.find(lines, &String.contains?(&1, first))
    unnamed = Enum.find(lines, &String.contains?(&1, second))

    assert named =~ ~s{name = "crooked ear"}
    assert unnamed =~ ~s{name = "#{shown(second)}"}
  end

  # Property 4: a place_tokens entry may state a name, and need not.
  test "an authored place_tokens entry may state a name" do
    {:ok, scene} =
      Entity.build("scene", %{
        "id" => "st0001-0000000008",
        "name" => "Named",
        "type" => "battle",
        "order" => 8,
        "tokens" => [%{"id" => "tk0001-0000000001"}],
        "place_tokens" => [
          %{"game_id" => "tk0001-0000000001-left", "x" => 10, "y" => 10, "name" => "left guard"},
          %{"game_id" => "tk0001-0000000001-right", "x" => 50, "y" => 50}
        ]
      })

    {:ok, _} = Store.put(scene)
    :ok = Game.reconcile()
    :ok = Game.run_action([:scene, :select], "st0001-0000000008")

    assert shown("tk0001-0000000001-left") == "left guard"
    assert shown("tk0001-0000000001-right") == placement("tk0001-0000000001-right").data.name
  end
end
