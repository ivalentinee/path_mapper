defmodule PathMapper.Game.Dump do
  @moduledoc false

  alias PathMapper.Game.State

  @version 1

  def serialize(%State{} = state, adventure_file, group_file) do
    %{
      version: @version,
      adventure_file: adventure_file,
      group_file: group_file,
      active_scene: state.active_scene,
      initiative: state.initiative,
      scenes:
        Map.new(state.scenes, fn {idx, scene} ->
          {to_string(idx), serialize_scene(scene)}
        end)
    }
  end

  defp serialize_scene(%State.Scene{} = scene) do
    base = %{
      index: scene.index,
      custom: scene.custom,
      map: serialize_map(scene.map),
      tokens: Enum.map(scene.tokens, &serialize_token/1),
      drawn_elements: Enum.map(scene.drawn_elements, &serialize_drawn_element/1)
    }

    if scene.custom do
      Map.put(base, :name, scene.name)
    else
      base
    end
  end

  defp serialize_map(%State.Scene.Map{} = map) do
    %{
      grid_size: map.grid_size,
      grid_line_width: map.grid_line_width,
      show_grid: map.show_grid,
      layers: Enum.map(map.layers, &serialize_layer/1),
      map_objects: Enum.map(map.map_objects, &serialize_map_object/1)
    }
    |> maybe_put(:width, map.width)
    |> maybe_put(:height, map.height)
  end

  defp serialize_layer(%State.Scene.Map.Layer{} = layer) do
    %{index: layer.index, show: layer.show, light: layer.light, highlight: layer.highlight}
  end

  defp serialize_map_object(%State.Scene.Map.MapObject{} = obj) do
    %{
      index: obj.index,
      layer_index: obj.layer_index,
      x: obj.x,
      y: obj.y,
      locked: obj.locked,
      show: obj.show
    }
  end

  defp serialize_token(%State.Scene.Token{} = token) do
    base = %{
      data_name: token.data.name,
      x: token.x,
      y: token.y,
      state: token.state,
      size: token.size,
      owner: token.owner
    }

    if token.data.image == nil do
      Map.put(base, :adhoc, %{
        label: token.data.name,
        owner: token.data.owner,
        size: token.data.size
      })
    else
      base
    end
  end

  defp serialize_drawn_element(%State.Scene.DrawnElement{} = element) do
    %{
      id: element.id,
      type: to_string(element.type),
      color: element.color,
      owner: element.owner,
      data: element.data
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
