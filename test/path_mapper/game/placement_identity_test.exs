defmodule PathMapper.Game.PlacementIdentityTest do
  @moduledoc """
  The design properties of "Game IDs for map tokens", exercised as written.

  Each test names the property it covers. Where a property is testable in the
  words it was approved in, it is tested that way rather than against a
  restatement of it.
  """
  use PathMapperWeb.ConnCase, async: false

  alias PathMapper.Game
  alias PathMapper.Game.GameId
  alias PathMapper.Session.Resolve

  setup do
    load_party()
    load_session()
    :ok = select_surface(1)
    %{characters: Resolve.characters()}
  end

  defp placements, do: Game.get_state().surface.tokens
  defp ids, do: Enum.map(placements(), & &1.game_id)

  # Property 1: each placement on a surface has an id unique among that surface's.
  test "no two placements on a surface share an id" do
    Enum.each(
      ["tk0001-0000000001", "tk0001-0000000001", "tk0001-0000000002"],
      &Game.run_action([:tokens, :add], &1)
    )

    assert ids() == Enum.uniq(ids())
    assert Enum.all?(ids(), &is_binary/1)
  end

  # Property 2: a placement's id identifies the declared token it was placed from.
  test "every placement's id names the token it was placed from" do
    Enum.each(placements(), fn placement ->
      assert GameId.token_id(placement.game_id) == placement.data.id
    end)
  end

  test "a placement made during play is given an id" do
    before = ids()
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")

    [minted] = ids() -- before
    assert GameId.token_id(minted) != nil
  end

  # Property 1 again, through the command path: the collision rule.
  test "placing onto an id the surface already holds is dismissed and reported" do
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")
    taken = hd(ids())
    count = length(placements())

    assert {:ok, [^taken]} =
             Game.run_action([:tokens, :add], {"tk0001-0000000001", %{game_id: taken}})

    assert length(placements()) == count
  end

  # Property 3: every operation on a placed token names it by that id.
  test "marking, moving and removing all act through the id" do
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000002")
    target = Enum.at(ids(), 1)

    :ok = Game.run_action([:tokens, target, :set_state], "dead")
    assert placement(target).state == "dead"

    :ok = Game.run_action([:tokens, target, :move], {500, 600, %{}})
    assert placement(target).x != nil

    :ok = Game.run_action([:tokens, :delete], target)
    assert placement(target) == nil
  end

  # Property 7: a command acts on exactly the placement its id matches.
  test "naming a placement the surface does not hold changes nothing" do
    before = placements()

    :ok = Game.run_action([:tokens, "tk0001-0000000001-nobody", :set_state], "dead")
    :ok = Game.run_action([:tokens, :delete], "tk0001-0000000001-nobody")
    :ok = Game.run_action([:tokens, "tk0001-0000000001-nobody", :move], {10, 10, %{}})

    assert placements() == before
  end

  # Property 4: placement order is independent of how ids sort.
  test "order is the order placed, not the order ids sort" do
    :ok =
      Game.run_action([:tokens, :add], {"tk0001-0000000002", %{game_id: "tk0001-0000000002-aaa"}})

    :ok =
      Game.run_action([:tokens, :add], {"tk0001-0000000001", %{game_id: "tk0001-0000000001-zzz"}})

    placed = ids()

    assert List.last(placed) == "tk0001-0000000001-zzz"
    refute placed == Enum.sort(placed)
  end

  # Property 8: a player's own token places once; extras as often as asked.
  test "a character's own token is placed once however often it is asked", %{
    characters: characters
  } do
    player = hd(characters)

    :ok = Game.run_action([:tokens, :character, :add], player.id)
    after_first = placements()

    assert {:ok, _dismissed} = Game.run_action([:tokens, :character, :add], player.id)
    assert placements() == after_first
  end

  test "an extra token is placed as often as asked, each with its own id", %{
    characters: characters
  } do
    player = hd(characters)
    count = length(placements())

    :ok = Game.run_action([:tokens, :character, :add_extra], {player.id, 0})
    :ok = Game.run_action([:tokens, :character, :add_extra], {player.id, 0})

    assert length(placements()) == count + 2
    assert ids() == Enum.uniq(ids())
  end

  # Property 6: a snapshot restores each placement under the id it was saved with.
  test "every placement comes back from a snapshot under the id it left with" do
    :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")
    saved = ids()

    {:ok, manifest} = Game.dump_state()
    manifest = Jason.decode!(Jason.encode!(manifest))

    Game.clear()
    characters = load_party()
    load_session()
    :ok = Game.restore_state(manifest)

    assert ids() == saved
  end

  defp placement(game_id), do: Enum.find(placements(), &(&1.game_id == game_id))
end
