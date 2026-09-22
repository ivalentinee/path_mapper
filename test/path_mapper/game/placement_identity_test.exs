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
  alias PathMapper.Game.State.Scene.Token, as: GameToken
  alias PathMapper.Groups
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store

  setup do
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    :ok = select_scene(1)
    :ok
  end

  defp placements, do: Game.get_state().scene.tokens
  defp ids, do: Enum.map(placements(), & &1.game_id)

  # Property 1: each placement on a scene has an id unique among that scene's.
  test "no two placements on a scene share an id" do
    Enum.each(0..3, fn i -> Game.run_action([:tokens, :add], i) end)

    assert ids() == Enum.uniq(ids())
    assert Enum.all?(ids(), &is_binary/1)
  end

  # Property 2: a placement's id identifies the declared token it was placed from.
  test "every placement's id names the token it was placed from" do
    Enum.each(placements(), fn placement ->
      assert GameId.token_id(placement.game_id) == placement.data.id
    end)
  end

  # Property 5: an entry may state its id; one that states none is given one.
  test "an authored place_tokens entry keeps the id it states" do
    assert "tk0001-0000000001-fallen" in ids()
    assert "tk0001-0000000001-standing" in ids()
  end

  test "a placement made during play is given an id" do
    before = ids()
    :ok = Game.run_action([:tokens, :add], 0)

    [minted] = ids() -- before
    assert GameId.token_id(minted) != nil
  end

  # Property 1 again, through the command path: the collision rule.
  test "placing onto an id the scene already holds is dismissed and reported" do
    taken = hd(ids())
    token = hd(Game.get_state().scene.data.tokens)
    count = length(placements())

    assert {:ok, [^taken]} =
             Game.run_action([:tokens, :add], {token.id, %{game_id: taken}})

    assert length(placements()) == count
  end

  # Property 3: every operation on a placed token names it by that id.
  test "marking, moving and removing all act through the id" do
    target = Enum.at(ids(), 1)

    :ok = Game.run_action([:tokens, target, :set_state], "dead")
    assert placement(target).state == "dead"

    :ok = Game.run_action([:tokens, target, :move], {500, 600, %{}})
    assert placement(target).x != nil

    :ok = Game.run_action([:tokens, :delete], target)
    assert placement(target) == nil
  end

  # Property 7: a command acts on exactly the placement its id matches.
  test "naming a placement the scene does not hold changes nothing" do
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
  test "a player's own token is placed once however often it is asked" do
    {:ok, group} = Groups.get_loaded()
    player = hd(group.players)

    :ok = Game.run_action([:tokens, :player, :add], player.id)
    after_first = placements()

    assert {:ok, _dismissed} = Game.run_action([:tokens, :player, :add], player.id)
    assert placements() == after_first
  end

  test "an extra token is placed as often as asked, each with its own id" do
    {:ok, group} = Groups.get_loaded()
    player = hd(group.players)
    count = length(placements())

    :ok = Game.run_action([:tokens, :player, :add_extra], {player.id, 0})
    :ok = Game.run_action([:tokens, :player, :add_extra], {player.id, 0})

    assert length(placements()) == count + 2
    assert ids() == Enum.uniq(ids())
  end

  # Property 6: a snapshot restores each placement under the id it was saved with.
  test "every placement comes back from a snapshot under the id it left with" do
    :ok = Game.run_action([:tokens, :add], 0)
    saved = ids()

    {:ok, manifest} = Game.dump_state()
    manifest = Jason.decode!(Jason.encode!(manifest))

    Game.clear()
    {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    :ok = Game.restore_state(manifest)

    assert ids() == saved
  end

  # The copy a game master pastes into an adventure names placements the same way
  # a snapshot does, so an arrangement can be taken out and authored back in.
  test "the place_tokens copy writes each placement's id" do
    copy = GameToken.to_place_records(placements(), 10)

    Enum.each(ids(), fn game_id -> assert copy =~ "game_id = \"#{game_id}\"" end)
  end

  # Two entries under one id is the mistake an adventure written against the old
  # form makes, since two entries for one token used to be ordinary.
  test "a scene declaring one id twice places it once and reports the rest" do
    {:ok, scene} =
      Entity.build("scene", %{
        "id" => "st0001-0000000009",
        "name" => "Doubled",
        "type" => "battle",
        "order" => 9,
        "tokens" => [%{"id" => "tk0001-0000000001"}],
        "place_tokens" => [
          %{"game_id" => "tk0001-0000000001-twice", "x" => 10, "y" => 10},
          %{"game_id" => "tk0001-0000000001-twice", "x" => 50, "y" => 50}
        ]
      })

    {:ok, _stored} = Store.put(scene)

    assert {:ok, ["tk0001-0000000001-twice"]} = Game.reconcile()

    :ok = Game.run_action([:scene, :select], "st0001-0000000009")

    assert ids() == ["tk0001-0000000001-twice"]
  end

  defp placement(game_id), do: Enum.find(placements(), &(&1.game_id == game_id))
end
