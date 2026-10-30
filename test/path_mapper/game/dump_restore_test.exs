defmodule PathMapper.Game.DumpRestoreTest do
  use ExUnit.Case

  import PathMapperWeb.TestHelpers

  alias PathMapper.Game
  alias PathMapper.Game.Dump
  alias PathMapper.Game.Palette
  alias PathMapper.Game.Restore
  alias PathMapper.Game.State
  alias PathMapper.Session.Commands

  setup do
    Game.clear()
    on_exit(fn -> Game.clear() end)
    :ok
  end

  defp round_trip(state) do
    json = state |> Dump.serialize() |> Jason.encode!() |> Jason.decode!()
    {:ok, snapshot} = Restore.read(json)
    {:ok, restored} = Restore.build(snapshot.data)
    restored
  end

  defp loaded_state do
    load_session()
    select_surface(1)
    Game.get_raw_state_for_test()
  end

  describe "what a snapshot says" do
    test "it is version 4 and asserts nothing about where it came from" do
      load_session()
      {:ok, manifest} = Game.dump_state()

      assert manifest.version == 4
      refute Elixir.Map.has_key?(manifest, :adventure_id)
      refute Elixir.Map.has_key?(manifest, :group_id)
    end

    test "it names surfaces by map id" do
      load_session()
      {:ok, manifest} = Game.dump_state()

      assert Elixir.Map.keys(manifest.surfaces) |> Enum.sort() ==
               ["mt0001-0000000001", "mt0001-0000000002"]
    end

    test "a surface carries no order, no custom flag and no roster" do
      load_session()
      {:ok, manifest} = Game.dump_state()
      surface = manifest.surfaces["mt0001-0000000001"]

      assert Elixir.Map.keys(surface) |> Enum.sort() == [:drawn_elements, :map, :tokens]
    end
  end

  describe "the round trip" do
    test "what the table was shown comes back" do
      restored = loaded_state() |> round_trip()
      assert restored.active_surface == "mt0001-0000000001"
    end

    test "initiative comes back" do
      load_session()
      select_surface(1)
      :ok = Game.run_action([:initiative, :add], %{name: "Goblin", value: 12})

      restored = Game.get_raw_state_for_test() |> round_trip()

      assert [%{name: "Goblin", value: 12}] = restored.initiative
    end

    test "a placement comes back, with the token the store still holds" do
      load_session()
      select_surface(1)
      :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")

      restored = Game.get_raw_state_for_test() |> round_trip()
      [token] = restored.surfaces["mt0001-0000000001"].tokens

      assert token.data.id == "tk0001-0000000001"
    end
  end

  describe "what the store does not hold" do
    test "a surface the store cannot match is not restored, and nothing is said" do
      state = %State{
        active_surface: "mt9999-0000000099",
        surfaces: %{
          "mt9999-0000000099" => %State.Surface{
            id: "mt9999-0000000099",
            map: %State.Surface.Map{layers: [], map_objects: []},
            tokens: [],
            drawn_elements: []
          }
        }
      }

      restored = round_trip(state)

      assert restored.surfaces == %{}
    end

    test "a placement whose token has gone is dropped, and the rest stay" do
      load_session()
      select_surface(1)
      :ok = Game.run_action([:tokens, :add], "tk0001-0000000001")
      :ok = Game.run_action([:tokens, :add], "tk0001-0000000002")

      json =
        Game.get_raw_state_for_test()
        |> Dump.serialize()
        |> Jason.encode!()
        |> Jason.decode!()

      :ok = Commands.remove("tk0001-0000000002")

      {:ok, snapshot} = Restore.read(json)
      {:ok, restored} = Restore.build(snapshot.data)

      ids = Enum.map(restored.surfaces["mt0001-0000000001"].tokens, & &1.data.id)
      assert ids == ["tk0001-0000000001"]
    end
  end

  describe "the version" do
    test "an older snapshot is refused by version rather than by content" do
      assert {:error, "Unsupported version: 3"} = Restore.read(%{"version" => 3})
    end

    test "a snapshot with no version is refused" do
      assert {:error, "Invalid format: missing version"} = Restore.read(%{})
    end
  end

  describe "restoring through the game" do
    test "a snapshot from another session is accepted, and matches what it can" do
      load_session()
      select_surface(1)
      {:ok, manifest} = Game.dump_state()
      manifest = Jason.decode!(Jason.encode!(manifest))

      Game.clear()
      load_session("two-shapes")

      assert :ok = Game.restore_state(manifest)
    end

    test "character colours survive a restore" do
      characters = load_party()
      load_session()
      select_surface(1)
      {:ok, manifest} = Game.dump_state()

      :ok = Game.restore_state(Jason.decode!(Jason.encode!(manifest)))

      character = hd(characters)
      assert Palette.resolve(character.id) == character.color
    end

    test "every declared map is in the list afterwards, not only the ones restored" do
      load_session()
      select_surface(1)
      {:ok, manifest} = Game.dump_state()
      manifest = Jason.decode!(Jason.encode!(manifest))

      :ok = Game.restore_state(manifest)

      assert length(Game.get_state().surface_list) == 2
    end
  end
end
