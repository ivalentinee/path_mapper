defmodule PathMapper.Game.Actions.Scene do
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene
  alias PathMapper.Game.Initialize
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Map.Layer, as: StateLayer
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  def action(%State{active_scene: id} = state, [:scene, :select], id) when is_binary(id) do
    {:ok, state}
  end

  def action(%State{} = state, [:scene, :select], id) when is_binary(id) do
    if Map.has_key?(state.scenes, id) do
      {:ok, Map.put(state, :active_scene, id)}
    else
      {:error, "No scene #{id} in this session"}
    end
  end

  def action(%State{} = state, [:scene, :unset], _) do
    {:ok, Map.put(state, :active_scene, nil)}
  end

  def action(%State{active_scene: nil} = state, [:scene, :reset], _), do: {:ok, state}

  def action(%State{} = state, [:scene, :reset], _) do
    scene = State.scene(state)

    if scene.custom do
      {:error, "Cannot reset custom scenes"}
    else
      {new_scene, dismissed} = Initialize.build_scene(scene.data, scene.order)
      {:ok, State.put_scene(state, new_scene), dismissed}
    end
  end

  def action(%State{active_scene: nil}, [:scene, :set_map], _data) do
    {:error, "No active scene"}
  end

  def action(%State{} = state, [:scene, :set_map], %{} = adventure_map) do
    scene = State.scene(state)
    old_data = scene.data

    # Build AdventureScene wrapper for the uploaded map
    new_adventure_scene = %AdventureScene{
      name: scene.name,
      type: "battle",
      map: adventure_map,
      tokens: if(old_data, do: old_data.tokens, else: []),
      place_tokens: []
    }

    # Build new state map from the uploaded data
    new_state_map = build_state_map(adventure_map, scene)

    new_scene = %{
      scene
      | data: new_adventure_scene,
        map: new_state_map,
        uploaded_map: true
    }

    {:ok, State.put_scene(state, new_scene)}
  end

  defp build_state_map(adventure_map, scene) do
    old_map = scene.map
    old_data_map = if(scene.data, do: scene.data.map)

    # Build layers preserving existing state by index
    new_layers =
      adventure_map.layers
      |> Enum.with_index()
      |> Enum.map(fn {adv_layer, _list_pos} ->
        old_layer = Enum.find(old_map.layers, &(&1.index == adv_layer.index))
        merge_layer(adv_layer, old_layer)
      end)

    # Build map objects preserving moved positions by name
    old_objects_with_data = build_old_objects_lookup(old_map.map_objects, old_data_map)

    new_map_objects =
      adventure_map.map_objects
      |> Enum.with_index()
      |> Enum.map(fn {adv_obj, index} ->
        merge_map_object(adv_obj, index, old_objects_with_data)
      end)

    %State.Scene.Map{
      width: adventure_map.width,
      height: adventure_map.height,
      grid_size: adventure_map.grid_size,
      grid_line_width: adventure_map.grid_line_width,
      show_grid: adventure_map.show_grid,
      layers: new_layers,
      map_objects: new_map_objects
    }
  end

  defp merge_layer(adv_layer, nil) do
    StateLayer.initialize({adv_layer, 0})
  end

  defp merge_layer(_adv_layer, old_layer) do
    old_layer
  end

  defp build_old_objects_lookup(old_state_objects, old_adv_map) do
    old_adv_objects =
      case old_adv_map do
        %{map_objects: objects} when is_list(objects) -> objects
        _ -> []
      end

    Enum.map(old_state_objects, fn obj_state ->
      adv_obj = Enum.at(old_adv_objects, obj_state.index)
      name = if adv_obj, do: adv_obj.name
      {name, obj_state, adv_obj}
    end)
  end

  defp merge_map_object(adv_obj, index, old_objects_with_data) do
    new_x = GeometryMapper.to_subpixels(adv_obj.x)
    new_y = GeometryMapper.to_subpixels(adv_obj.y)

    # Find old object by name match
    case Enum.find(old_objects_with_data, fn {name, _, _} -> name == adv_obj.name end) do
      {_, old_state, old_adv} when not is_nil(old_adv) ->
        # Check if the GM moved this object from its original ORA position
        old_ora_x = GeometryMapper.to_subpixels(old_adv.x)
        old_ora_y = GeometryMapper.to_subpixels(old_adv.y)
        was_moved = old_state.x != old_ora_x or old_state.y != old_ora_y

        %State.Scene.Map.MapObject{
          index: index,
          layer_index: adv_obj.layer_index,
          x: if(was_moved, do: old_state.x, else: new_x),
          y: if(was_moved, do: old_state.y, else: new_y),
          locked: old_state.locked,
          show: adv_obj.show
        }

      _ ->
        %State.Scene.Map.MapObject{
          index: index,
          layer_index: adv_obj.layer_index,
          x: new_x,
          y: new_y,
          locked: true,
          show: adv_obj.show
        }
    end
  end
end
