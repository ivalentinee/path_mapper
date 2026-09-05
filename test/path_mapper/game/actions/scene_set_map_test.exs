defmodule PathMapper.Game.Actions.SceneSetMapTest do
  use ExUnit.Case, async: true

  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap
  alias PathMapper.Adventures.Adventure.Scene.Map.AdditionalLayer
  alias PathMapper.Adventures.Adventure.Scene.Map.Layer, as: AdventureLayer
  alias PathMapper.Adventures.Adventure.Scene.Map.MapObject, as: AdventureMapObject
  alias PathMapper.Game.Actions.Scene, as: SceneActions
  alias PathMapper.Game.State
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  defp build_adventure_map(opts \\ []) do
    %AdventureMap{
      width: opts[:width] || 1000,
      height: opts[:height] || 800,
      grid_size: opts[:grid_size] || 50,
      grid_line_width: opts[:grid_line_width] || 1,
      show_grid: Keyword.get(opts, :show_grid, true),
      floors: opts[:floors] || [],
      layers:
        opts[:layers] ||
          [
            %AdventureLayer{
              name: "Ground",
              image: "/custom/ground.png",
              images: [],
              index: 1,
              x: 0,
              y: 0,
              width: 1000,
              height: 800,
              tags: [],
              show: true,
              light: "bright",
              floor: nil
            }
          ],
      map_objects: opts[:map_objects] || [],
      grid:
        opts[:grid] ||
          %AdditionalLayer{
            name: "Grid",
            image: "/custom/grid.png",
            x: 0,
            y: 0,
            width: 1000,
            height: 800,
            tags: ["grid-50"]
          },
      fow: opts[:fow]
    }
  end

  defp build_custom_scene(opts \\ []) do
    %State.Scene{
      index: opts[:index] || 0,
      custom: true,
      name: opts[:name] || "Test Scene",
      data: opts[:data],
      map: opts[:map] || State.Scene.Map.blank(),
      tokens: opts[:tokens] || [],
      drawn_elements: opts[:drawn_elements] || []
    }
  end

  defp build_state(scene) do
    %State{
      active_scene: scene.index,
      scenes: %{scene.index => scene}
    }
  end

  test "returns error when no active scene" do
    state = %State{active_scene: nil, scenes: %{}}
    assert {:error, "No active scene"} = SceneActions.action(state, [:scene, :set_map], %{})
  end

  test "sets map on custom scene" do
    scene = build_custom_scene()
    state = build_state(scene)
    adventure_map = build_adventure_map()

    assert {:ok, new_state} = SceneActions.action(state, [:scene, :set_map], adventure_map)

    new_scene = new_state.scenes[0]
    assert new_scene.data != nil
    assert new_scene.data.map == adventure_map
    assert new_scene.data.name == "Test Scene"
    assert new_scene.data.type == "battle"

    # State map updated
    assert new_scene.map.width == 1000
    assert new_scene.map.height == 800
    assert new_scene.map.grid_size == 50
    assert new_scene.map.show_grid == true
    assert length(new_scene.map.layers) == 1
    assert hd(new_scene.map.layers).index == 1
  end

  test "preserves tokens and drawn elements on re-upload" do
    token = %State.Scene.Token{
      x: 100,
      y: 200,
      state: "alive",
      size: 50,
      owner: "Alice",
      data: %{name: "Hero"}
    }

    drawn = %State.Scene.DrawnElement{
      id: "1",
      type: :fill,
      color: "#ff0000",
      owner: "GM",
      data: %{}
    }

    scene = build_custom_scene(tokens: [token], drawn_elements: [drawn])
    state = build_state(scene)
    adventure_map = build_adventure_map()

    assert {:ok, new_state} = SceneActions.action(state, [:scene, :set_map], adventure_map)

    new_scene = new_state.scenes[0]
    assert length(new_scene.tokens) == 1
    assert hd(new_scene.tokens).owner == "Alice"
    assert length(new_scene.drawn_elements) == 1
    assert hd(new_scene.drawn_elements).id == "1"
  end

  test "preserves layer state (show/light/highlight) on re-upload" do
    # First upload
    adventure_map = build_adventure_map()
    scene = build_custom_scene()
    state = build_state(scene)

    {:ok, state_after_first} = SceneActions.action(state, [:scene, :set_map], adventure_map)

    # Simulate toggling the layer's show to false
    scene1 = state_after_first.scenes[0]
    modified_layer = %{hd(scene1.map.layers) | show: false, light: "dim", highlight: true}
    modified_map = %{scene1.map | layers: [modified_layer]}
    scene1 = %{scene1 | map: modified_map}
    state_modified = %{state_after_first | scenes: %{0 => scene1}}

    # Re-upload same map
    {:ok, state_after_second} =
      SceneActions.action(state_modified, [:scene, :set_map], adventure_map)

    new_layer = hd(state_after_second.scenes[0].map.layers)
    assert new_layer.show == false
    assert new_layer.light == "dim"
    assert new_layer.highlight == true
  end

  test "preserves moved map object position by name on re-upload" do
    obj = %AdventureMapObject{
      name: "Door",
      image: "/custom/door.png",
      x: 100,
      y: 200,
      width: 50,
      height: 50,
      layer_index: 1,
      tags: [],
      show: true
    }

    adventure_map = build_adventure_map(map_objects: [obj])

    # First upload
    scene = build_custom_scene()
    state = build_state(scene)
    {:ok, state1} = SceneActions.action(state, [:scene, :set_map], adventure_map)

    # Simulate GM moving the object
    scene1 = state1.scenes[0]
    moved_obj = %{hd(scene1.map.map_objects) | x: 5000, y: 6000}
    modified_map = %{scene1.map | map_objects: [moved_obj]}
    scene1 = %{scene1 | map: modified_map}
    state_modified = %{state1 | scenes: %{0 => scene1}}

    # Re-upload - object position should be preserved
    {:ok, state2} = SceneActions.action(state_modified, [:scene, :set_map], adventure_map)

    result_obj = hd(state2.scenes[0].map.map_objects)
    assert result_obj.x == 5000
    assert result_obj.y == 6000
  end

  test "uses new ORA position for unmoved objects on re-upload" do
    obj = %AdventureMapObject{
      name: "Door",
      image: "/custom/door.png",
      x: 100,
      y: 200,
      width: 50,
      height: 50,
      layer_index: 1,
      tags: [],
      show: true
    }

    adventure_map = build_adventure_map(map_objects: [obj])

    # First upload
    scene = build_custom_scene()
    state = build_state(scene)
    {:ok, state1} = SceneActions.action(state, [:scene, :set_map], adventure_map)

    # Re-upload with new position (object was not moved by GM)
    new_obj = %{obj | x: 300, y: 400}
    new_map = build_adventure_map(map_objects: [new_obj])
    {:ok, state2} = SceneActions.action(state1, [:scene, :set_map], new_map)

    result_obj = hd(state2.scenes[0].map.map_objects)
    assert result_obj.x == GeometryMapper.to_subpixels(300)
    assert result_obj.y == GeometryMapper.to_subpixels(400)
  end

  test "new layers get fresh state from ORA tags" do
    layer1 = %AdventureLayer{
      name: "Ground",
      image: "/custom/ground.png",
      images: [],
      index: 1,
      x: 0,
      y: 0,
      width: 1000,
      height: 800,
      tags: [],
      show: true,
      light: "bright",
      floor: nil
    }

    layer2 = %AdventureLayer{
      name: "Upper",
      image: "/custom/upper.png",
      images: [],
      index: 2,
      x: 0,
      y: 0,
      width: 1000,
      height: 800,
      tags: ["hide", "dim"],
      show: false,
      light: "dim",
      floor: nil
    }

    # First upload with layer1 only
    map1 = build_adventure_map(layers: [layer1])
    scene = build_custom_scene()
    state = build_state(scene)
    {:ok, state1} = SceneActions.action(state, [:scene, :set_map], map1)

    # Re-upload with both layers
    map2 = build_adventure_map(layers: [layer1, layer2])
    {:ok, state2} = SceneActions.action(state1, [:scene, :set_map], map2)

    layers = state2.scenes[0].map.layers
    assert length(layers) == 2
    new_layer = Enum.find(layers, &(&1.index == 2))
    assert new_layer.show == false
    assert new_layer.light == "dim"
  end
end
