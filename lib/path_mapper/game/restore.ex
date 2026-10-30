defmodule PathMapper.Game.Restore do
  @moduledoc """
  A snapshot read back into game state.

  What a snapshot names and the store does not hold is not restored, and nothing
  is reported: a snapshot carries what stood on a surface, never which surfaces
  exist, so an id it names that nothing answers to is a surface that is simply
  not there. `PathMapper.Game.restore_state/1` reconciles afterwards, which is
  what puts every declared map back in the list.
  """

  alias PathMapper.Game.State
  alias PathMapper.Session
  alias PathMapper.Session.Resolve

  @version 4

  def read(data) when is_map(data) do
    with :ok <- validate_version(data), do: {:ok, %{data: data}}
  end

  def build(data) when is_map(data) do
    {:ok,
     %State{
       active_surface: data["active_surface"],
       surfaces: build_surfaces(data["surfaces"] || %{}),
       initiative: build_initiative(data["initiative"] || [])
     }}
  end

  defp validate_version(%{"version" => @version}), do: :ok
  defp validate_version(%{"version" => v}), do: {:error, "Unsupported version: #{v}"}
  defp validate_version(_), do: {:error, "Invalid format: missing version"}

  defp build_surfaces(surfaces) do
    surfaces
    |> Enum.flat_map(fn {id, data} ->
      case Resolve.surface(id) do
        nil -> []
        map -> [{id, build_surface(id, data, map)}]
      end
    end)
    |> Map.new()
  end

  defp build_surface(id, data, map) do
    %State.Surface{
      id: id,
      name: map.name,
      data: map,
      map: build_map(data["map"] || %{}),
      tokens: build_tokens(data["tokens"] || []),
      drawn_elements: build_drawn_elements(data["drawn_elements"] || [])
    }
  end

  defp build_tokens(tokens) do
    tokens
    |> Enum.map(&build_token/1)
    |> Enum.reject(&is_nil/1)
  end

  # A token placed from nothing the store holds carries its own definition, so it
  # survives a round trip that the store cannot answer for.
  defp build_token(%{"adhoc" => adhoc} = data) when is_map(adhoc) do
    placed(data, %Session.Token{
      id: adhoc["id"] || data["data_id"],
      name: adhoc["label"],
      owner: adhoc["owner"] || "none",
      image: nil,
      size: adhoc["size"] || 1
    })
  end

  defp build_token(data) do
    case Resolve.declared_token(data["data_id"]) do
      nil -> nil
      token -> placed(data, token)
    end
  end

  defp placed(data, %Session.Token{} = token) do
    %State.Surface.Token{
      game_id: data["game_id"],
      name: data["name"],
      x: data["x"],
      y: data["y"],
      state: data["state"],
      size: data["size"],
      owner: data["owner"],
      data: token
    }
  end

  defp build_map(map_data) do
    %State.Surface.Map{
      width: map_data["width"],
      height: map_data["height"],
      grid_size: map_data["grid_size"],
      grid_line_width: map_data["grid_line_width"],
      show_grid: map_data["show_grid"],
      layers: Enum.map(map_data["layers"] || [], &build_layer/1),
      map_objects: Enum.map(map_data["map_objects"] || [], &build_map_object/1)
    }
  end

  defp build_layer(data) do
    %State.Surface.Map.Layer{
      index: data["index"],
      show: data["show"],
      light: data["light"],
      highlight: data["highlight"] || false
    }
  end

  defp build_map_object(data) do
    %State.Surface.Map.MapObject{
      index: data["index"],
      name: data["name"],
      layer_index: data["layer_index"],
      x: data["x"],
      y: data["y"],
      locked: data["locked"],
      show: data["show"]
    }
  end

  defp build_drawn_elements(elements) do
    elements
    |> Enum.map(&build_drawn_element/1)
    |> Enum.reject(&is_nil/1)
  end

  defp build_drawn_element(data) when is_map(data) do
    case parse_element_type(data["type"]) do
      nil ->
        nil

      type ->
        %State.Surface.DrawnElement{
          id: data["id"] || to_string(System.unique_integer([:positive])),
          type: type,
          color: data["color"],
          owner: data["owner"],
          data: data["data"] || %{}
        }
    end
  end

  defp build_drawn_element(_), do: nil

  @element_types %{
    "fill" => :fill,
    "rect" => :rect,
    "line" => :line,
    "circle" => :circle,
    "text" => :text,
    "path" => :path
  }

  defp parse_element_type(type) when is_binary(type), do: @element_types[type]
  defp parse_element_type(_), do: nil

  defp build_initiative(entries) do
    Enum.map(entries, fn entry ->
      %{
        id: entry["id"] || to_string(System.unique_integer([:positive])),
        name: entry["name"],
        value: entry["value"],
        owner: entry["owner"]
      }
    end)
  end
end
