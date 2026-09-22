defmodule PathMapper.Game.PlaceTokenRoundTripTest do
  @moduledoc """
  A copied arrangement re-imports as the arrangement it was copied from.

  The exporter and the importer were maintained apart and drifted: the copy wrote
  an owner precisely where it differed from the declaration, and the entry schema
  cast no owner at all, so Ecto dropped it in silence. The work a copy exists to
  save was lost and nothing said so.
  """
  use PathMapperWeb.ConnCase, async: false

  alias PathMapper.Adventures.Adventure.Scene.Map, as: SceneMap
  alias PathMapper.Game
  alias PathMapper.Game.State.Scene.Token, as: GameToken
  alias PathMapper.Geometry.Mapper
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store

  @fallen "tk0001-0000000001-fallen"

  setup do
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    :ok = select_scene(1)
    :ok
  end

  defp placements, do: Game.get_state().scene.tokens
  defp placement(game_id), do: Enum.find(placements(), &(&1.game_id == game_id))

  # What a placement *is*, for comparison across a copy. The name is compared as
  # resolved rather than as stored: a copy always states one, so a placement that
  # carried none of its own returns carrying the declaration's, which is the same
  # thing to everyone who reads it.
  defp described(placement) do
    placement
    |> Elixir.Map.take([:game_id, :state, :owner])
    |> Elixir.Map.put(:called, GameToken.displayed_name(placement))
  end

  defp grid do
    case Game.get_state().scene do
      %{map: %{grid_size: size}} when is_integer(size) and size > 0 -> size
      _ -> SceneMap.default_grid_size()
    end
  end

  # Copies the live arrangement out, then builds a scene from it and selects it -
  # which is what a game master does by pasting into an adventure and reloading.
  defp round_trip(scene_id) do
    copy = GameToken.to_place_records(placements(), grid())
    {:ok, parsed} = :tomerl.parse(copy)

    # The same map, because a cell is a cell of *that* grid. Pasting into a scene
    # with a different grid means different cells, which is the point.
    source = Enum.find(Store.all(), &(&1.kind == "scene"))

    {:ok, scene} =
      Entity.build("scene", %{
        "id" => scene_id,
        "name" => "Round trip",
        "type" => "battle",
        "order" => 7,
        "map_id" => source.data.map_id,
        "tokens" => Enum.map(placements(), &%{"id" => &1.data.id}),
        "place_tokens" => parsed["place_tokens"]
      })

    {:ok, _} = Store.put(scene)
    :ok = Game.reconcile()
    :ok = Game.run_action([:scene, :select], scene_id)
  end

  # Property 1, and the one that fails on any fact taught to only one side.
  test "every placement returns as the placement it left as" do
    :ok = Game.run_action([:tokens, @fallen, :set_owner], "npc")
    :ok = Game.run_action([:tokens, @fallen, :set_name], "crooked ear")

    before = Enum.map(placements(), &described/1)
    positions = Elixir.Map.new(placements(), &{&1.game_id, {&1.x, &1.y}})

    round_trip("st0001-0000000007")

    assert Enum.map(placements(), &described/1) == before

    Enum.each(placements(), fn placement ->
      {x, y} = Elixir.Map.fetch!(positions, placement.game_id)
      assert placement.x == x
      assert placement.y == y
    end)
  end

  # Property 2, on the fact that was actually being dropped.
  test "an owner the copy states is the owner the load gives" do
    :ok = Game.run_action([:tokens, @fallen, :set_owner], "npc")
    declared = placement(@fallen).data.owner

    refute placement(@fallen).owner == declared

    round_trip("st0001-0000000006")

    assert placement(@fallen).owner == "npc"
  end

  # Property 3.
  test "an entry omitting a fact takes it from the declaration" do
    {:ok, scene} =
      Entity.build("scene", %{
        "id" => "st0001-0000000005",
        "name" => "Sparse",
        "type" => "battle",
        "order" => 5,
        "tokens" => [%{"id" => "tk0001-0000000001"}],
        "place_tokens" => [%{"game_id" => "tk0001-0000000001-bare", "x" => 3, "y" => 4}]
      })

    {:ok, _} = Store.put(scene)
    :ok = Game.reconcile()
    :ok = Game.run_action([:scene, :select], "st0001-0000000005")

    placed = placement("tk0001-0000000001-bare")

    assert placed.owner == placed.data.owner
    assert placed.name == nil
    assert GameToken.displayed_name(placed) == placed.data.name
    assert placed.state == "alive"
  end

  describe "positions in grid cells" do
    test "a token on the grid writes a whole cell" do
      copy = GameToken.to_place_records(placements(), grid())

      assert copy =~ ~r/x = \d+,/
      refute copy =~ "subpixel"
    end

    test "a position survives the map being re-exported at another scale" do
      # The same entry, read against a grid twice the size, lands twice as far out
      # in pixels - which is the same cell, and so the same place on the map.
      assert Mapper.from_cells(3, 100) ==
               2 * Mapper.from_cells(3, 50)
    end

    test "a token off the grid keeps its offset to a tenth of a cell" do
      cells =
        Mapper.to_cells(
          Mapper.to_subpixels(15.5 * 50),
          50
        )

      assert cells == 15.5
    end
  end
end
