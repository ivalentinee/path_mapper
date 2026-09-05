defmodule PathMapper.Game.Dump do
  @moduledoc false

  alias PathMapper.Game.State

  @version 2

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

    base = if scene.custom, do: Map.put(base, :name, scene.name), else: base

    case scene do
      %{custom: true, data: %{map: map}} when not is_nil(map) ->
        Map.put(base, :custom_map, serialize_custom_map(map))

      _ ->
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

  defp serialize_custom_map(map) do
    %{
      width: map.width,
      height: map.height,
      grid_size: map.grid_size,
      grid_line_width: map.grid_line_width,
      show_grid: map.show_grid,
      floors: map.floors,
      layers: Enum.map(map.layers || [], &serialize_custom_layer/1),
      map_objects: Enum.map(map.map_objects || [], &serialize_custom_map_object/1),
      grid: serialize_custom_additional_layer(map.grid),
      fow: serialize_custom_additional_layer(map.fow)
    }
  end

  defp serialize_custom_layer(layer) do
    %{
      name: layer.name,
      image: layer.image,
      images: Enum.map(layer.images || [], &serialize_sub_image/1),
      index: layer.index,
      x: layer.x,
      y: layer.y,
      width: layer.width,
      height: layer.height,
      tags: layer.tags,
      show: layer.show,
      light: layer.light,
      floor: layer.floor
    }
  end

  defp serialize_sub_image(img) do
    %{
      image: img.image || img[:image],
      x: img.x || img[:x],
      y: img.y || img[:y],
      width: img.width || img[:width],
      height: img.height || img[:height]
    }
  end

  defp serialize_custom_map_object(obj) do
    %{
      name: obj.name,
      image: obj.image,
      x: obj.x,
      y: obj.y,
      width: obj.width,
      height: obj.height,
      layer_index: obj.layer_index,
      tags: obj.tags,
      show: obj.show
    }
  end

  defp serialize_custom_additional_layer(nil), do: nil

  defp serialize_custom_additional_layer(layer) do
    %{
      name: layer.name,
      image: layer.image,
      x: layer.x,
      y: layer.y,
      width: layer.width,
      height: layer.height,
      tags: layer.tags
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
