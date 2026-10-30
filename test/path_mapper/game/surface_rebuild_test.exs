defmodule PathMapper.Game.SurfaceRebuildTest do
  use ExUnit.Case, async: true

  alias PathMapper.Game.State
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Session.Map, as: AdventureMap
  alias PathMapper.Session.Map.AdditionalLayer
  alias PathMapper.Session.Map.Layer, as: AdventureLayer
  alias PathMapper.Session.Map.MapObject, as: AdventureMapObject

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
              image: "/upload/ground.png",
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
            image: "/upload/grid.png",
            x: 0,
            y: 0,
            width: 1000,
            height: 800,
            tags: ["grid-50"]
          },
      fow: opts[:fow]
    }
  end

  defp build_surface(opts \\ []) do
    %State.Surface{
      id: opts[:id] || "mt0001-0000000001",
      name: opts[:name] || "Test Surface",
      data: opts[:data] || build_adventure_map(),
      map: opts[:map] || State.Surface.Map.initialize(build_adventure_map()),
      tokens: opts[:tokens] || [],
      drawn_elements: opts[:drawn_elements] || []
    }
  end

  defp build_state(surface) do
    %State{
      active_surface: surface.id,
      surfaces: %{surface.id => surface}
    }
  end

  # Re-declaring a map is what `Game.reconcile/0` does with a map the store has
  # replaced by id. The action layer no longer has a say in it.
  defp redeclare(state, map) do
    surface = State.surface(state)
    {:ok, State.put_surface(state, State.Surface.rebuild(surface, map))}
  end

  test "sets map on custom scene" do
    scene = build_surface()
    state = build_state(scene)
    adventure_map = build_adventure_map()

    assert {:ok, new_state} = redeclare(state, adventure_map)

    new_scene = State.surface(new_state)
    assert new_scene.data != nil
    assert new_scene.data == adventure_map

    # State map updated
    assert new_scene.map.width == 1000
    assert new_scene.map.height == 800
    assert new_scene.map.grid_size == 50
    assert new_scene.map.show_grid == true
    assert length(new_scene.map.layers) == 1
    assert hd(new_scene.map.layers).index == 1
  end

  test "preserves tokens and drawn elements on re-upload" do
    token = %State.Surface.Token{
      x: 100,
      y: 200,
      state: "alive",
      size: 50,
      owner: "Alice",
      data: %{name: "Hero"}
    }

    drawn = %State.Surface.DrawnElement{
      id: "1",
      type: :fill,
      color: "#ff0000",
      owner: "GM",
      data: %{}
    }

    scene = build_surface(tokens: [token], drawn_elements: [drawn])
    state = build_state(scene)
    adventure_map = build_adventure_map()

    assert {:ok, new_state} = redeclare(state, adventure_map)

    new_scene = State.surface(new_state)
    assert length(new_scene.tokens) == 1
    assert hd(new_scene.tokens).owner == "Alice"
    assert length(new_scene.drawn_elements) == 1
    assert hd(new_scene.drawn_elements).id == "1"
  end

  test "preserves layer state (show/light/highlight) on re-upload" do
    # First upload
    adventure_map = build_adventure_map()
    scene = build_surface()
    state = build_state(scene)

    {:ok, state_after_first} = redeclare(state, adventure_map)

    # Simulate toggling the layer's show to false
    scene1 = State.surface(state_after_first)
    modified_layer = %{hd(scene1.map.layers) | show: false, light: "dim", highlight: true}
    modified_map = %{scene1.map | layers: [modified_layer]}
    scene1 = %{scene1 | map: modified_map}
    state_modified = %{state_after_first | surfaces: %{scene1.id => scene1}}

    # Re-upload same map
    {:ok, state_after_second} =
      redeclare(state_modified, adventure_map)

    new_layer = hd(State.surface(state_after_second).map.layers)
    assert new_layer.show == false
    assert new_layer.light == "dim"
    assert new_layer.highlight == true
  end

  test "preserves moved map object position by name on re-upload" do
    obj = %AdventureMapObject{
      name: "Door",
      image: "/upload/door.png",
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
    scene = build_surface()
    state = build_state(scene)
    {:ok, state1} = redeclare(state, adventure_map)

    # Simulate GM moving the object
    scene1 = State.surface(state1)
    moved_obj = %{hd(scene1.map.map_objects) | x: 5000, y: 6000}
    modified_map = %{scene1.map | map_objects: [moved_obj]}
    scene1 = %{scene1 | map: modified_map}
    state_modified = %{state1 | surfaces: %{scene1.id => scene1}}

    # Re-upload - object position should be preserved
    {:ok, state2} = redeclare(state_modified, adventure_map)

    result_obj = hd(State.surface(state2).map.map_objects)
    assert result_obj.x == 5000
    assert result_obj.y == 6000
  end

  test "uses new ORA position for unmoved objects on re-upload" do
    obj = %AdventureMapObject{
      name: "Door",
      image: "/upload/door.png",
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
    scene = build_surface()
    state = build_state(scene)
    {:ok, state1} = redeclare(state, adventure_map)

    # Re-upload with new position (object was not moved by GM)
    new_obj = %{obj | x: 300, y: 400}
    new_map = build_adventure_map(map_objects: [new_obj])
    {:ok, state2} = redeclare(state1, new_map)

    result_obj = hd(State.surface(state2).map.map_objects)
    assert result_obj.x == GeometryMapper.to_subpixels(300)
    assert result_obj.y == GeometryMapper.to_subpixels(400)
  end

  # Objects sort by layer index, so a link added on [L1] to a map whose
  # furniture sits on [L9] arrives at the front of the list and moves every
  # other object's index along by one. State rows are addressed positionally, so
  # the shift used to put each object where its neighbour stood - the object
  # keeping its own image and its own link, which is why it read as one piece in
  # the wrong place rather than as two pieces swapped.
  describe "a map that gained an object" do
    test "leaves every object where its own export puts it" do
      state = build_state(build_surface())

      {:ok, before} = redeclare(state, build_adventure_map(map_objects: [food(), table()]))
      stale = dumped(before)

      {:ok, after_edit} =
        redeclare(before, build_adventure_map(map_objects: [exit_link(), food(), table()]))

      {:ok, restored} = redeclare(restore_into(after_edit, stale), objects_after_edit())

      assert placed(restored) == [
               {"Выход", 1010, 1414},
               {"Еда", 1346, 199},
               {"Стол", 1326, 170}
             ]
    end

    test "still keeps an object the game master had moved" do
      state = build_state(build_surface())
      {:ok, before} = redeclare(state, build_adventure_map(map_objects: [food(), table()]))

      moved = move(before, "Еда", 1500, 300)
      stale = dumped(moved)

      {:ok, after_edit} = redeclare(moved, objects_after_edit())
      {:ok, restored} = redeclare(restore_into(after_edit, stale), objects_after_edit())

      assert placed(restored) == [
               {"Выход", 1010, 1414},
               {"Еда", 1500, 300},
               {"Стол", 1326, 170}
             ]
    end

    # The dumps a game master already has were written before a row carried a
    # name, so they say only an index and a layer. The layer is enough: these
    # rows are [L9] and the object that arrived is [L1].
    test "places an old nameless dump by its layer rather than by its index" do
      state = build_state(build_surface())
      {:ok, before} = redeclare(state, build_adventure_map(map_objects: [food(), table()]))
      stale = before |> dumped() |> without_names()

      {:ok, after_edit} = redeclare(before, objects_after_edit())
      {:ok, restored} = redeclare(restore_into(after_edit, stale), objects_after_edit())

      assert placed(restored) == [
               {"Выход", 1010, 1414},
               {"Еда", 1346, 199},
               {"Стол", 1326, 170}
             ]
    end

    test "an old nameless dump still keeps what the game master had moved" do
      state = build_state(build_surface())
      {:ok, before} = redeclare(state, build_adventure_map(map_objects: [food(), table()]))
      stale = before |> move("Стол", 400, 500) |> dumped() |> without_names()

      {:ok, after_edit} = redeclare(before, objects_after_edit())
      {:ok, restored} = redeclare(restore_into(after_edit, stale), objects_after_edit())

      assert placed(restored) == [
               {"Выход", 1010, 1414},
               {"Еда", 1346, 199},
               {"Стол", 400, 500}
             ]
    end

    # Hiding an object is a mid-game decision like moving it. It used to be
    # taken from the declaration on every reconcile, so a hidden object came
    # back visible on the next restore.
    test "keeps an object the game master had hidden" do
      state = build_state(build_surface())
      {:ok, before} = redeclare(state, build_adventure_map(map_objects: [food(), table()]))
      stale = before |> hide("Еда") |> dumped()

      {:ok, after_edit} = redeclare(before, objects_after_edit())
      {:ok, restored} = redeclare(restore_into(after_edit, stale), objects_after_edit())

      assert shown(restored) == [{"Выход", true}, {"Еда", false}, {"Стол", true}]
    end

    test "shows again what the export now shows, where nobody hid it" do
      state = build_state(build_surface())
      {:ok, before} = redeclare(state, build_adventure_map(map_objects: [food(), table()]))

      hidden_by_export = %{food() | show: false}

      {:ok, after_edit} =
        redeclare(before, build_adventure_map(map_objects: [hidden_by_export, table()]))

      assert shown(after_edit) == [{"Еда", false}, {"Стол", true}]
    end

    # Two barrels are two objects, and the second must not claim the first's
    # row and leave itself without one.
    test "gives objects that share a name a row each" do
      left = %{food() | name: "Barrel", x: 10, y: 10}
      right = %{food() | name: "Barrel", x: 900, y: 900}
      state = build_state(build_surface())

      {:ok, declared} = redeclare(state, build_adventure_map(map_objects: [left, right]))

      assert placed(declared) == [{"Barrel", 10, 10}, {"Barrel", 900, 900}]
    end
  end

  defp without_names(objects), do: Enum.map(objects, &Map.delete(&1, "name"))

  defp objects_after_edit,
    do: build_adventure_map(map_objects: [exit_link(), food(), table()])

  defp object(name, x, y, layer_index),
    do: %AdventureMapObject{
      name: name,
      image: "/upload/#{:erlang.phash2(name)}.png",
      x: x,
      y: y,
      width: 50,
      height: 50,
      layer_index: layer_index,
      tags: [],
      show: true
    }

  defp exit_link, do: object("Выход", 1010, 1414, 1)
  defp food, do: object("Еда", 1346, 199, 9)
  defp table, do: object("Стол", 1326, 170, 9)

  defp placed(state) do
    Enum.map(State.surface(state).map.map_objects, fn object ->
      {object.name, GeometryMapper.from_subpixels(object.x) |> round(),
       GeometryMapper.from_subpixels(object.y) |> round()}
    end)
  end

  defp shown(state),
    do: Enum.map(State.surface(state).map.map_objects, &{&1.name, &1.show})

  defp hide(state, name) do
    surface = State.surface(state)

    objects =
      Enum.map(surface.map.map_objects, fn object ->
        if object.name == name, do: %{object | show: false}, else: object
      end)

    State.put_surface(state, %{surface | map: %{surface.map | map_objects: objects}})
  end

  defp move(state, name, x, y) do
    surface = State.surface(state)

    objects =
      Enum.map(surface.map.map_objects, fn object ->
        if object.name == name,
          do: %{
            object
            | x: GeometryMapper.to_subpixels(x),
              y: GeometryMapper.to_subpixels(y)
          },
          else: object
      end)

    State.put_surface(state, %{surface | map: %{surface.map | map_objects: objects}})
  end

  # What a .pmload or a snapshot carries: the state alone, through the same
  # serialiser and reader a client would use.
  defp dumped(state) do
    surface = State.surface(state)

    surface.map.map_objects
    |> Enum.map(fn object ->
      %{
        "index" => object.index,
        "name" => object.name,
        "layer_index" => object.layer_index,
        "x" => object.x,
        "y" => object.y,
        "locked" => object.locked,
        "show" => object.show
      }
    end)
  end

  defp restore_into(state, objects) do
    surface = State.surface(state)

    restored =
      Enum.map(objects, fn data ->
        %State.Surface.Map.MapObject{
          index: data["index"],
          name: data["name"],
          layer_index: data["layer_index"],
          x: data["x"],
          y: data["y"],
          locked: data["locked"],
          show: data["show"]
        }
      end)

    State.put_surface(state, %{surface | map: %{surface.map | map_objects: restored}})
  end

  test "new layers get fresh state from ORA tags" do
    layer1 = %AdventureLayer{
      name: "Ground",
      image: "/upload/ground.png",
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
      image: "/upload/upper.png",
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
    scene = build_surface()
    state = build_state(scene)
    {:ok, state1} = redeclare(state, map1)

    # Re-upload with both layers
    map2 = build_adventure_map(layers: [layer1, layer2])
    {:ok, state2} = redeclare(state1, map2)

    layers = State.surface(state2).map.layers
    assert length(layers) == 2
    new_layer = Enum.find(layers, &(&1.index == 2))
    assert new_layer.show == false
    assert new_layer.light == "dim"
  end

  # Regression: `reset_position` read `surface.data.map.map_objects` while `data`
  # is a map, which carries its objects directly. It raised on every press.
  describe "resetting a map object" do
    setup do
      PathMapper.Game.clear()
      on_exit(fn -> PathMapper.Game.clear() end)
      PathMapperWeb.TestHelpers.load_session()
      :ok = PathMapperWeb.TestHelpers.select_surface(1)
      :ok
    end

    test "puts an object back where its map declares it" do
      [object | _] = PathMapper.Game.get_state().surface.map.map_objects

      :ok = PathMapper.Game.run_action([:map_objects, object.index, :toggle_lock], nil)
      :ok = PathMapper.Game.run_action([:map_objects, object.index, :move], {500, 600})
      moved = Enum.at(PathMapper.Game.get_state().surface.map.map_objects, object.index)
      assert {moved.x, moved.y} != {object.x, object.y}

      :ok = PathMapper.Game.run_action([:map_objects, object.index, :reset_position], nil)
      back = Enum.at(PathMapper.Game.get_state().surface.map.map_objects, object.index)

      assert {back.x, back.y} == {object.x, object.y}
    end
  end
end
