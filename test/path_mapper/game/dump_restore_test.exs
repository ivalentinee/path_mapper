defmodule PathMapper.Game.DumpRestoreTest do
  use ExUnit.Case, async: true

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene
  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap
  alias PathMapper.Adventures.Adventure.Scene.Map.AdditionalLayer
  alias PathMapper.Adventures.Adventure.Scene.Map.Layer, as: AdventureLayer
  alias PathMapper.Adventures.Adventure.Scene.Map.MapObject, as: AdventureMapObject
  alias PathMapper.Adventures.Adventure.Scene.Token, as: AdventureToken
  alias PathMapper.Game.Dump
  alias PathMapper.Game.Restore
  alias PathMapper.Game.State

  @adventure_id "tt0001-0000000001"
  @group_id "tg0001-0000000001"

  defp build_adventure do
    %Adventure{
      title: "Test Adventure",
      id: @adventure_id,
      file: "tt0001-0000000001-test-adventure.zip",
      scenes: [
        %AdventureScene{
          id: "sc0001-0000000001",
          ref: "01",
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
            %AdventureToken{
              id: "tk0001-0000000001",
              name: "Goblin",
              owner: "enemy",
              image: "/tokens/goblin.png",
              size: 1
            },
            %AdventureToken{
              id: "tk0001-0000000002",
              name: "Hero",
              owner: "pl0001-0000000001",
              image: "/tokens/hero.png",
              size: 1
            }
          ],
          place_tokens: []
        }
      ]
    }
  end

  defp restore_json(json, adventure) do
    with {:ok, snapshot} <- Restore.read(Jason.decode!(json)),
         do: Restore.build(snapshot.data, adventure)
  end

  defp build_state do
    %State{
      active_scene: "sc0001-0000000001",
      initiative: [
        %{id: "1", name: "Hero", value: 18, owner: "Alice"},
        %{id: "2", name: "Goblin", value: 12, owner: "enemy"}
      ],
      scenes: %{
        "sc0001-0000000001" => %State.Scene{
          id: "sc0001-0000000001",
          order: 0,
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
              owner: "pl0001-0000000001",
              data: %AdventureToken{
                id: "tk0001-0000000002",
                name: "Hero",
                owner: "pl0001-0000000001",
                image: "/tokens/hero.png",
                size: 1
              }
            }
          ]
        }
      }
    }
  end

  describe "round-trip" do
    test "serialize then restore produces equivalent state" do
      state = build_state()
      adventure = build_adventure()

      serialized = Dump.serialize(state, build_adventure(), @group_id)
      json = Jason.encode!(serialized)
      {:ok, restored} = restore_json(json, adventure)

      assert restored.active_scene == state.active_scene
      assert length(restored.initiative) == 2
      assert length(Map.keys(restored.scenes)) == 1

      scene = restored.scenes["sc0001-0000000001"]
      assert scene.order == 0
      assert scene.data.name == "Scene 1"
      assert length(scene.tokens) == 1

      token = hd(scene.tokens)
      assert token.x == 1000
      assert token.y == 2000
      assert token.state == "alive"
      assert token.owner == "pl0001-0000000001"
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
      serialized = Dump.serialize(state, build_adventure(), @group_id)
      json = Jason.encode!(serialized)
      {:ok, restored} = restore_json(json, build_adventure())

      [first | _] = restored.initiative
      assert is_binary(first.id)
      assert is_binary(first.name)
      assert is_integer(first.value)
    end
  end

  describe "validation" do
    test "reads back the ids a snapshot names" do
      json = Jason.encode!(Dump.serialize(build_state(), build_adventure(), @group_id))

      assert {:ok, %{adventure_id: @adventure_id, group_id: @group_id}} =
               Restore.read(Jason.decode!(json))
    end

    test "carries a nil group id when the snapshot names no group" do
      json = Jason.encode!(Dump.serialize(build_state(), build_adventure(), nil))

      assert {:ok, %{adventure_id: @adventure_id, group_id: nil}} =
               Restore.read(Jason.decode!(json))
    end

    test "rejects a snapshot naming no adventure" do
      json = Jason.encode!(%{version: 3})

      assert {:error, "Snapshot names no adventure"} = Restore.read(Jason.decode!(json))
    end

    test "rejects missing version" do
      json = Jason.encode!(%{})

      assert {:error, "Invalid format: missing version"} = Restore.read(Jason.decode!(json))
    end

    test "rejects unknown version" do
      json = Jason.encode!(%{version: 99})

      assert {:error, "Unsupported version: 99"} = Restore.read(Jason.decode!(json))
    end
  end

  describe "edge cases" do
    test "skips tokens not found in adventure" do
      state = build_state()
      # Add a token referencing a non-existent adventure token
      scene = State.scene(state)

      extra_token = %State.Scene.Token{
        x: 0,
        y: 0,
        state: "alive",
        size: 50,
        owner: "enemy",
        data: %AdventureToken{
          id: "tk0001-0000000099",
          name: "Deleted Monster",
          owner: "enemy",
          image: "/x.png",
          size: 1
        }
      }

      scene = %{scene | tokens: scene.tokens ++ [extra_token]}
      state = %{state | scenes: %{0 => scene}}

      serialized = Dump.serialize(state, build_adventure(), @group_id)
      json = Jason.encode!(serialized)
      {:ok, restored} = restore_json(json, build_adventure())

      # "Deleted Monster" not in adventure, so skipped on restore
      assert length(restored.scenes["sc0001-0000000001"].tokens) == 1
      assert hd(restored.scenes["sc0001-0000000001"].tokens).data.name == "Hero"
    end

    test "drawn elements including :path survive round-trip" do
      state = build_state()
      scene = State.scene(state)

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

      serialized = Dump.serialize(state, build_adventure(), @group_id)
      json = Jason.encode!(serialized)
      {:ok, restored} = restore_json(json, build_adventure())

      assert length(restored.scenes["sc0001-0000000001"].drawn_elements) == 2
      [fill_el, path_el] = restored.scenes["sc0001-0000000001"].drawn_elements
      assert fill_el.type == :fill
      assert path_el.type == :path
      assert path_el.color == "#00ff00"
      assert path_el.owner == "Alice"
      assert path_el.data["points"] == [[10, 20], [30, 40], [50, 60]]
      assert path_el.data["width"] == 8
    end

    test "empty state round-trips" do
      state = %State{active_scene: nil, initiative: [], scenes: %{}}
      serialized = Dump.serialize(state, build_adventure(), @group_id)
      json = Jason.encode!(serialized)
      {:ok, restored} = restore_json(json, build_adventure())

      assert restored.active_scene == nil
      assert restored.initiative == []
      assert restored.scenes == %{}
    end

    test "renaming and renumbering a scene and its tokens breaks no reference" do
      serialized = Dump.serialize(build_state(), build_adventure(), @group_id)

      relabelled = build_adventure()
      scene = Enum.at(relabelled.scenes, 0)
      [goblin, hero] = scene.tokens

      scene = %{
        scene
        | ref: "07.2",
          name: "Renamed entirely",
          tokens: [%{goblin | name: "Гоблин"}, %{hero | name: "Retyped Hero"}]
      }

      relabelled = %{relabelled | scenes: [scene]}

      {:ok, restored} = restore_json(Jason.encode!(serialized), relabelled)

      assert [token] = restored.scenes["sc0001-0000000001"].tokens
      assert token.data.id == "tk0001-0000000002"
      assert token.data.name == "Retyped Hero"
      assert restored.scenes["sc0001-0000000001"].data.ref == "07.2"
      assert restored.scenes["sc0001-0000000001"].data.name == "Renamed entirely"
    end

    test "inserting a scene ahead of it does not shift a snapshot" do
      serialized = Dump.serialize(build_state(), build_adventure(), @group_id)

      inserted = %AdventureScene{
        id: "sc0001-0000000000",
        ref: "00",
        name: "A prologue added later",
        type: "battle",
        map: %AdventureMap{
          grid_size: 100,
          grid_line_width: 1,
          show_grid: true,
          layers: [],
          map_objects: []
        },
        tokens: [],
        place_tokens: []
      }

      grown = build_adventure()
      grown = %{grown | scenes: [inserted | grown.scenes]}

      {:ok, restored} = restore_json(Jason.encode!(serialized), grown)

      # The snapshot named sc0001-0000000001, which is now at position 1, not 0.
      assert restored.scenes["sc0001-0000000001"].id == "sc0001-0000000001"
      assert [token] = restored.scenes["sc0001-0000000001"].tokens
      assert token.data.name == "Hero"
    end

    test "a roster entry no blob declares survives the round trip" do
      uploaded = %AdventureToken{
        id: "tk0001-0000000009",
        name: "Skeleton Warrior",
        owner: "npc",
        image: "/upload/aaaa000000000009.png",
        size: 2
      }

      state = build_state()
      scene = State.scene(state)
      scene = %{scene | data: %{scene.data | tokens: scene.data.tokens ++ [uploaded]}}
      state = %{state | scenes: %{0 => scene}}

      serialized = Dump.serialize(state, build_adventure(), @group_id)
      carried = serialized.scenes["sc0001-0000000001"].roster

      assert Enum.map(carried, & &1.name) == ["Skeleton Warrior"]

      {:ok, restored} = restore_json(Jason.encode!(serialized), build_adventure())
      names = Enum.map(restored.scenes["sc0001-0000000001"].data.tokens, & &1.name)

      assert names == ["Goblin", "Hero", "Skeleton Warrior"]
      entry = List.last(restored.scenes["sc0001-0000000001"].data.tokens)
      assert entry.image == "/upload/aaaa000000000009.png"
      assert entry.size == 2
      assert entry.owner == "npc"
    end

    test "a blob-declared token keeps the blob's definition, not the snapshot's" do
      serialized = Dump.serialize(build_state(), build_adventure(), @group_id)

      assert serialized.scenes["sc0001-0000000001"].roster == []

      edited = build_adventure()
      [goblin | rest] = Enum.at(edited.scenes, 0).tokens
      goblin = %{goblin | image: "/adventure/edited0000000001.png"}
      scene = %{Enum.at(edited.scenes, 0) | tokens: [goblin | rest]}
      edited = %{edited | scenes: [scene | tl(edited.scenes)]}

      {:ok, restored} = restore_json(Jason.encode!(serialized), edited)
      back = Enum.find(restored.scenes["sc0001-0000000001"].data.tokens, &(&1.name == "Goblin"))

      assert back.image == "/adventure/edited0000000001.png"
    end

    test "a malformed roster entry is skipped and the rest of the roster stands" do
      serialized = Dump.serialize(build_state(), build_adventure(), @group_id)

      serialized =
        put_in(serialized.scenes["sc0001-0000000001"].roster, [
          %{"owner" => "npc"},
          %{
            id: "tk0001-0000000010",
            name: "Kept",
            owner: "npc",
            image: "/upload/bbbb000000000001.png",
            size: 1
          }
        ])

      {:ok, restored} = restore_json(Jason.encode!(serialized), build_adventure())
      names = Enum.map(restored.scenes["sc0001-0000000001"].data.tokens, & &1.name)

      assert names == ["Goblin", "Hero", "Kept"]
    end

    test "a map uploaded onto an adventure scene round-trips" do
      uploaded =
        %AdventureMap{
          width: 640,
          height: 480,
          grid_size: 50,
          grid_line_width: 1,
          show_grid: true,
          floors: [],
          layers: [
            %AdventureLayer{
              name: "Uploaded",
              image: "/upload/aaaa000000000001.png",
              images: [],
              index: 1,
              x: 0,
              y: 0,
              width: 640,
              height: 480,
              tags: [],
              show: true,
              light: "bright",
              floor: 0
            }
          ],
          map_objects: [],
          grid: nil,
          fow: nil
        }

      adventure = build_adventure()
      blob_scene = Enum.at(adventure.scenes, 0)

      state = %State{
        active_scene: "sc0001-0000000001",
        initiative: [],
        scenes: %{
          "sc0001-0000000001" => %State.Scene{
            id: "sc0001-0000000001",
            order: 0,
            custom: false,
            uploaded_map: true,
            data: %{blob_scene | map: uploaded},
            map: %State.Scene.Map{
              grid_size: 50,
              grid_line_width: 1,
              show_grid: true,
              layers: [],
              map_objects: []
            },
            tokens: [],
            drawn_elements: []
          }
        }
      }

      json = Jason.encode!(Dump.serialize(state, build_adventure(), @group_id))
      {:ok, restored} = restore_json(json, adventure)
      scene = restored.scenes["sc0001-0000000001"]

      assert scene.uploaded_map
      refute scene.custom
      assert [layer] = scene.data.map.layers
      assert layer.image == "/upload/aaaa000000000001.png"
      assert scene.data.map.width == 640
    end

    test "custom scene with uploaded map round-trips" do
      custom_map = %AdventureMap{
        width: 1000,
        height: 800,
        grid_size: 50,
        grid_line_width: 2,
        show_grid: true,
        floors: [0, 1],
        layers: [
          %AdventureLayer{
            name: "Ground",
            image: "/upload/123.png",
            images: [%{image: "/upload/456.png", x: 0, y: 0, width: 1000, height: 800}],
            index: 1,
            x: 0,
            y: 0,
            width: 1000,
            height: 800,
            tags: ["floor-0"],
            show: true,
            light: "bright",
            floor: 0
          }
        ],
        map_objects: [
          %AdventureMapObject{
            name: "Door",
            image: "/upload/789.png",
            x: 100,
            y: 200,
            width: 50,
            height: 50,
            layer_index: 1,
            tags: [],
            show: true
          }
        ],
        grid: %AdditionalLayer{
          name: "Grid",
          image: "/upload/grid.png",
          x: 0,
          y: 0,
          width: 1000,
          height: 800,
          tags: ["grid-50"]
        },
        fow: nil
      }

      custom_adventure_scene = %AdventureScene{
        name: "Custom Map",
        type: "battle",
        map: custom_map,
        tokens: [],
        place_tokens: []
      }

      state = %State{
        active_scene: "sc0001-0000000002",
        scenes: %{
          "sc0001-0000000001" => build_state().scenes["sc0001-0000000001"],
          "sc0001-0000000002" => %State.Scene{
            id: "sc0001-0000000002",
            order: 1,
            custom: true,
            name: "Custom Map",
            data: custom_adventure_scene,
            map: %State.Scene.Map{
              width: 1000,
              height: 800,
              grid_size: 50,
              grid_line_width: 2,
              show_grid: true,
              layers: [
                %State.Scene.Map.Layer{index: 1, show: true, light: "bright", highlight: false}
              ],
              map_objects: [
                %State.Scene.Map.MapObject{
                  index: 0,
                  layer_index: 1,
                  x: 1000,
                  y: 2000,
                  locked: true,
                  show: true
                }
              ]
            },
            tokens: [],
            drawn_elements: []
          }
        }
      }

      serialized = Dump.serialize(state, build_adventure(), @group_id)
      json = Jason.encode!(serialized)
      {:ok, restored} = restore_json(json, build_adventure())

      custom = restored.scenes["sc0001-0000000002"]
      assert custom.custom == true
      assert custom.name == "Custom Map"
      assert custom.data != nil
      assert custom.data.map.width == 1000
      assert custom.data.map.height == 800
      assert custom.data.map.grid_size == 50
      assert custom.data.map.grid_line_width == 2
      assert custom.data.map.show_grid == true
      assert custom.data.map.floors == [0, 1]

      assert length(custom.data.map.layers) == 1
      layer = hd(custom.data.map.layers)
      assert layer.name == "Ground"
      assert layer.image == "/upload/123.png"
      assert length(layer.images) == 1
      assert layer.index == 1
      assert layer.tags == ["floor-0"]

      assert length(custom.data.map.map_objects) == 1
      obj = hd(custom.data.map.map_objects)
      assert obj.name == "Door"
      assert obj.image == "/upload/789.png"
      assert obj.x == 100

      assert custom.data.map.grid != nil
      assert custom.data.map.grid.image == "/upload/grid.png"
      assert custom.data.map.fow == nil

      # State map preserved
      assert custom.map.grid_size == 50
      assert length(custom.map.layers) == 1
      assert hd(custom.map.layers).index == 1
    end

    test "custom scene without uploaded data round-trips (backward compat)" do
      state = %State{
        active_scene: "sc0001-0000000001",
        scenes: %{
          "sc0001-0000000001" => %State.Scene{
            id: "sc0001-0000000001",
            order: 0,
            custom: true,
            name: "Blank Custom",
            data: nil,
            map: State.Scene.Map.blank(),
            tokens: [],
            drawn_elements: []
          }
        }
      }

      serialized = Dump.serialize(state, build_adventure(), @group_id)
      json = Jason.encode!(serialized)
      {:ok, restored} = restore_json(json, build_adventure())

      custom = restored.scenes["sc0001-0000000001"]
      assert custom.custom == true
      assert custom.name == "Blank Custom"
      assert custom.data == nil
    end
  end
end
