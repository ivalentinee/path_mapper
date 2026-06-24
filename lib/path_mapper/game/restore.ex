defmodule PathMapper.Game.Restore do
  @moduledoc false

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game.State

  def restore(json_string, %Adventure{} = adventure, group) do
    with {:ok, data} <- decode_json(json_string),
         :ok <- validate_version(data),
         :ok <- validate_adventure(data, adventure),
         :ok <- validate_group(data, group) do
      build_state(data, adventure)
    end
  end

  defp decode_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, "Invalid JSON"}
    end
  end

  defp validate_version(%{"version" => 1}), do: :ok
  defp validate_version(%{"version" => v}), do: {:error, "Unsupported version: #{v}"}
  defp validate_version(_), do: {:error, "Invalid format: missing version"}

  defp validate_adventure(%{"adventure_file" => file}, %Adventure{file: file}), do: :ok

  defp validate_adventure(%{"adventure_file" => dump_file}, %Adventure{file: loaded_file}) do
    {:error, "Adventure mismatch: dump is for '#{dump_file}', loaded is '#{loaded_file}'"}
  end

  defp validate_adventure(_, _), do: :ok

  defp validate_group(%{"group_file" => file}, group) when not is_nil(group) do
    if group.file == file,
      do: :ok,
      else: {:error, "Group mismatch: dump is for '#{file}', loaded is '#{group.file}'"}
  end

  defp validate_group(_, _), do: :ok

  defp build_state(data, adventure) do
    scenes = build_scenes(data["scenes"] || %{}, adventure)
    initiative = build_initiative(data["initiative"] || [])

    {:ok,
     %State{
       active_scene: data["active_scene"],
       scenes: scenes,
       initiative: initiative
     }}
  end

  defp build_scenes(scenes_map, adventure) do
    scenes_map
    |> Enum.map(fn {index_str, scene_data} ->
      index = String.to_integer(index_str)

      cond do
        scene_data["custom"] == true ->
          {index, build_custom_scene(scene_data, index, adventure)}

        adventure_scene = Enum.at(adventure.scenes, index) ->
          {index, build_scene(scene_data, adventure_scene, index, adventure)}

        true ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp build_scene(scene_data, adventure_scene, index, adventure) do
    %State.Scene{
      index: index,
      name: adventure_scene.name,
      data: adventure_scene,
      map: build_map(scene_data["map"] || %{}),
      tokens: build_tokens(scene_data["tokens"] || [], adventure_scene, adventure),
      drawn_elements: build_drawn_elements(scene_data["drawn_elements"] || [])
    }
  end

  defp build_custom_scene(scene_data, index, adventure) do
    %State.Scene{
      index: index,
      custom: true,
      name: scene_data["name"],
      data: nil,
      map: build_map(scene_data["map"] || %{}),
      tokens: build_tokens(scene_data["tokens"] || [], nil, adventure),
      drawn_elements: build_drawn_elements(scene_data["drawn_elements"] || [])
    }
  end

  defp build_map(map_data) do
    %State.Scene.Map{
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
    %State.Scene.Map.Layer{
      index: data["index"],
      show: data["show"],
      light: data["light"],
      highlight: data["highlight"] || false
    }
  end

  defp build_map_object(data) do
    %State.Scene.Map.MapObject{
      index: data["index"],
      layer_index: data["layer_index"],
      x: data["x"],
      y: data["y"],
      locked: data["locked"],
      show: data["show"]
    }
  end

  defp build_tokens(tokens_data, adventure_scene, adventure) do
    tokens_data
    |> Enum.map(&build_token(&1, adventure_scene, adventure))
    |> Enum.reject(&is_nil/1)
  end

  defp build_token(data, adventure_scene, adventure) do
    # Ad-hoc tokens carry their own definition
    if data["adhoc"] do
      adhoc = data["adhoc"]

      adventure_token = %Adventure.Scene.Token{
        name: adhoc["label"] || data["data_name"],
        owner: adhoc["owner"] || "none",
        image: nil,
        size: adhoc["size"] || 1
      }

      %State.Scene.Token{
        x: data["x"],
        y: data["y"],
        state: data["state"],
        size: data["size"],
        owner: data["owner"],
        data: adventure_token
      }
    else
      build_adventure_token(data, adventure_scene, adventure)
    end
  end

  defp build_adventure_token(data, adventure_scene, adventure) do
    adventure_token =
      case adventure_scene do
        %{tokens: tokens} -> Enum.find(tokens, &(&1.name == data["data_name"]))
        _ -> nil
      end

    adventure_token =
      adventure_token ||
        Adventure.find_token_by_name(adventure, data["data_name"]) ||
        find_global_token(data["data_name"])

    case adventure_token do
      nil ->
        nil

      token ->
        %State.Scene.Token{
          x: data["x"],
          y: data["y"],
          state: data["state"],
          size: data["size"],
          owner: data["owner"],
          data: token
        }
    end
  end

  defp find_global_token(name) do
    case Enum.find(PathMapper.GlobalTokens.get(), fn entry -> entry.token.name == name end) do
      %{token: token} -> token
      _ -> nil
    end
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
        %State.Scene.DrawnElement{
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
    "text" => :text
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
