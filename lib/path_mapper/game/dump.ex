defmodule PathMapper.Game.Dump do
  @moduledoc false

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game.State

  @version 3

  def serialize(%State{} = state, adventure, group_id) do
    %{
      version: @version,
      adventure_id: adventure.id,
      group_id: group_id,
      active_scene: state.active_scene,
      initiative: state.initiative,
      scenes:
        Map.new(state.scenes, fn {_idx, scene} ->
          {scene.id, serialize_scene(scene, blob_roster(adventure, scene))}
        end)
    }
  end

  defp blob_roster(_adventure, %State.Scene{custom: true}), do: []

  defp blob_roster(adventure, %State.Scene{id: id}) do
    case Adventure.find_scene_by_id(adventure, id) do
      %{tokens: tokens} when is_list(tokens) -> tokens
      _ -> []
    end
  end

  defp serialize_scene(%State.Scene{} = scene, blob_roster) do
    base = %{
      order: scene.order,
      custom: scene.custom,
      uploaded_map: scene.uploaded_map,
      map: serialize_map(scene.map),
      roster: serialize_roster(scene, blob_roster),
      tokens: Enum.map(scene.tokens, &serialize_token/1),
      drawn_elements: Enum.map(scene.drawn_elements, &serialize_drawn_element/1)
    }

    base = if scene.custom, do: Map.put(base, :name, scene.name), else: base

    if ((scene.custom or scene.uploaded_map) and scene.data) && scene.data.map do
      Map.put(base, :custom_map, serialize_custom_map(scene.data.map))
    else
      base
    end
  end

  defp serialize_roster(%State.Scene{data: %{tokens: tokens}}, blob_roster)
       when is_list(tokens) do
    declared = MapSet.new(blob_roster, & &1.id)

    tokens
    |> Enum.reject(&MapSet.member?(declared, &1.id))
    |> Enum.map(&%{id: &1.id, name: &1.name, owner: &1.owner, image: &1.image, size: &1.size})
  end

  defp serialize_roster(_scene, _blob_roster), do: []

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
      data_id: token.data.id,
      x: token.x,
      y: token.y,
      state: token.state,
      size: token.size,
      owner: token.owner
    }

    if token.data.image == nil do
      Map.put(base, :adhoc, %{
        id: token.data.id,
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
