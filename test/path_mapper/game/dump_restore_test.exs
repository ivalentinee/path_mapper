defmodule PathMapper.Game.DumpRestoreTest do
  use ExUnit.Case, async: true

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene
  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap
  alias PathMapper.Adventures.Adventure.Scene.Token, as: AdventureToken
  alias PathMapper.Game.Dump
  alias PathMapper.Game.Restore
  alias PathMapper.Game.State

  @adventure_file "test-adventure.zip"
  @group_file "test-group.zip"

  defp build_adventure do
    %Adventure{
      title: "Test Adventure",
      file: @adventure_file,
      scenes: [
        %AdventureScene{
          name: "Scene 1",
          type: "encounter",
          map: %AdventureMap{
            grid_size: 100,
            grid_line_width: 1,
            show_grid: true,
            layers: [],
            map_objects: []
          },
          tokens: [
            %AdventureToken{name: "Goblin", owner: "enemy", image: "/tokens/goblin.png", size: 1},
            %AdventureToken{name: "Hero", owner: "Alice", image: "/tokens/hero.png", size: 1}
          ],
          place_tokens: []
        }
      ]
    }
  end

  defp build_state do
    %State{
      active_scene: 0,
      initiative: [
        %{id: "1", name: "Hero", value: 18, owner: "Alice"},
        %{id: "2", name: "Goblin", value: 12, owner: "enemy"}
      ],
      scenes: %{
        0 => %State.Scene{
          index: 0,
          data: Enum.at(build_adventure().scenes, 0),
          map: %State.Scene.Map{
            grid_size: 100,
            grid_line_width: 1,
            show_grid: true,
            layers: [
              %State.Scene.Map.Layer{index: 0, show: true, light: "bright", highlight: true}
            ],
            map_objects: [
              %State.Scene.Map.MapObject{
                index: 0,
                layer_index: 0,
                x: 500,
                y: 600,
                locked: false,
                show: true
              }
            ]
          },
          tokens: [
            %State.Scene.Token{
              x: 1000,
              y: 2000,
              state: "alive",
              size: 100,
              owner: "Alice",
              data: %AdventureToken{
                name: "Hero",
                owner: "Alice",
                image: "/tokens/hero.png",
                size: 1
              }
            }
          ]
        }
      }
    }
  end

  defp build_group do
    %{file: @group_file}
  end

  describe "round-trip" do
    test "serialize then restore produces equivalent state" do
      state = build_state()
      adventure = build_adventure()
      group = build_group()

      serialized = Dump.serialize(state, @adventure_file, @group_file)
      json = Jason.encode!(serialized)
      {:ok, restored} = Restore.restore(json, adventure, group)

      assert restored.active_scene == state.active_scene
      assert length(restored.initiative) == 2
      assert length(Map.keys(restored.scenes)) == 1

      scene = restored.scenes[0]
      assert scene.index == 0
      assert scene.data.name == "Scene 1"
      assert length(scene.tokens) == 1

      token = hd(scene.tokens)
      assert token.x == 1000
      assert token.y == 2000
      assert token.state == "alive"
      assert token.owner == "Alice"
      assert token.data.name == "Hero"

      map = scene.map
      assert map.grid_size == 100
      assert map.show_grid == true
      assert length(map.layers) == 1
      assert hd(map.layers).highlight == true
      assert length(map.map_objects) == 1

      obj = hd(map.map_objects)
      assert obj.x == 500
      assert obj.locked == false
    end

    test "initiative atom keys survive round-trip" do
      state = build_state()
      serialized = Dump.serialize(state, @adventure_file, @group_file)
      json = Jason.encode!(serialized)
      {:ok, restored} = Restore.restore(json, build_adventure(), build_group())

      [first | _] = restored.initiative
      assert is_binary(first.id)
      assert is_binary(first.name)
      assert is_integer(first.value)
    end
  end

  describe "validation" do
    test "rejects wrong adventure" do
      state = build_state()
      serialized = Dump.serialize(state, "other-adventure.zip", @group_file)
      json = Jason.encode!(serialized)

      assert {:error, "Adventure mismatch" <> _} =
               Restore.restore(json, build_adventure(), build_group())
    end

    test "rejects wrong group" do
      state = build_state()
      serialized = Dump.serialize(state, @adventure_file, "other-group.zip")
      json = Jason.encode!(serialized)

      assert {:error, "Group mismatch" <> _} =
               Restore.restore(json, build_adventure(), build_group())
    end

    test "rejects missing version" do
      json = Jason.encode!(%{})

      assert {:error, "Invalid format: missing version"} =
               Restore.restore(json, build_adventure(), build_group())
    end

    test "rejects unknown version" do
      json = Jason.encode!(%{version: 99})

      assert {:error, "Unsupported version: 99"} =
               Restore.restore(json, build_adventure(), build_group())
    end
  end

  describe "edge cases" do
    test "skips tokens not found in adventure" do
      state = build_state()
      # Add a token referencing a non-existent adventure token
      scene = state.scenes[0]

      extra_token = %State.Scene.Token{
        x: 0,
        y: 0,
        state: "alive",
        size: 50,
        owner: "enemy",
        data: %AdventureToken{name: "Deleted Monster", owner: "enemy", image: "/x.png", size: 1}
      }

      scene = %{scene | tokens: scene.tokens ++ [extra_token]}
      state = %{state | scenes: %{0 => scene}}

      serialized = Dump.serialize(state, @adventure_file, @group_file)
      json = Jason.encode!(serialized)
      {:ok, restored} = Restore.restore(json, build_adventure(), build_group())

      # "Deleted Monster" not in adventure, so skipped on restore
      assert length(restored.scenes[0].tokens) == 1
      assert hd(restored.scenes[0].tokens).data.name == "Hero"
    end

    test "drawn elements including :path survive round-trip" do
      state = build_state()
      scene = state.scenes[0]

      drawn_elements = [
        %State.Scene.DrawnElement{
          id: "1",
          type: :fill,
          color: "#ff0000",
          owner: "GM",
          data: %{"x" => 1, "y" => 2}
        },
        %State.Scene.DrawnElement{
          id: "2",
          type: :path,
          color: "#00ff00",
          owner: "Alice",
          data: %{"points" => [[10, 20], [30, 40], [50, 60]], "width" => 8}
        }
      ]

      scene = %{scene | drawn_elements: drawn_elements}
      state = %{state | scenes: %{0 => scene}}

      serialized = Dump.serialize(state, @adventure_file, @group_file)
      json = Jason.encode!(serialized)
      {:ok, restored} = Restore.restore(json, build_adventure(), build_group())

      assert length(restored.scenes[0].drawn_elements) == 2
      [fill_el, path_el] = restored.scenes[0].drawn_elements
      assert fill_el.type == :fill
      assert path_el.type == :path
      assert path_el.color == "#00ff00"
      assert path_el.owner == "Alice"
      assert path_el.data["points"] == [[10, 20], [30, 40], [50, 60]]
      assert path_el.data["width"] == 8
    end

    test "empty state round-trips" do
      state = %State{active_scene: nil, initiative: [], scenes: %{}}
      serialized = Dump.serialize(state, @adventure_file, @group_file)
      json = Jason.encode!(serialized)
      {:ok, restored} = Restore.restore(json, build_adventure(), build_group())

      assert restored.active_scene == nil
      assert restored.initiative == []
      assert restored.scenes == %{}
    end
  end
end
