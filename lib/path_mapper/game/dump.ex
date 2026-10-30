defmodule PathMapper.Game.Dump do
  @moduledoc """
  Game state written out as a snapshot.

  A snapshot asserts nothing about where it came from. It used to name the
  adventure and the group it was taken against, and restoring refused a
  mismatch; both are gone, so what is left is a version, what the table was
  shown, and what stands on each surface. Matching a snapshot to a session is
  the client's concern, as assembling one already was.
  """

  alias PathMapper.Game.State

  @version 4

  def serialize(%State{} = state) do
    %{
      version: @version,
      active_surface: state.active_surface,
      initiative: state.initiative,
      surfaces: Map.new(state.surfaces, fn {id, surface} -> {id, serialize_surface(surface)} end)
    }
  end

  defp serialize_surface(%State.Surface{} = surface) do
    %{
      map: serialize_map(surface.map),
      tokens: Enum.map(surface.tokens, &serialize_token/1),
      drawn_elements: Enum.map(surface.drawn_elements, &serialize_drawn_element/1)
    }
  end

  defp serialize_map(%State.Surface.Map{} = map) do
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

  defp serialize_layer(%State.Surface.Map.Layer{} = layer) do
    %{index: layer.index, show: layer.show, light: layer.light, highlight: layer.highlight}
  end

  defp serialize_map_object(%State.Surface.Map.MapObject{} = obj) do
    %{
      index: obj.index,
      name: obj.name,
      layer_index: obj.layer_index,
      x: obj.x,
      y: obj.y,
      locked: obj.locked,
      show: obj.show
    }
  end

  defp serialize_token(%State.Surface.Token{} = token) do
    base = %{
      game_id: token.game_id,
      name: token.name,
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

  defp serialize_drawn_element(%State.Surface.DrawnElement{} = element) do
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
