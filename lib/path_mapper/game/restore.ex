defmodule PathMapper.Game.Restore do
  @moduledoc false

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene
  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap
  alias PathMapper.Adventures.Adventure.Scene.Map.AdditionalLayer
  alias PathMapper.Adventures.Adventure.Scene.Map.Layer, as: AdventureLayer
  alias PathMapper.Adventures.Adventure.Scene.Map.MapObject, as: AdventureMapObject
  alias PathMapper.Game.Actions.Tokens.Find
  alias PathMapper.Game.State

  def read(data) when is_map(data) do
    with :ok <- validate_version(data),
         {:ok, adventure_id} <- fetch_adventure_id(data) do
      {:ok, %{data: data, adventure_id: adventure_id, group_id: data["group_id"]}}
    end
  end

  def build(data, %Adventure{} = adventure) when is_map(data) do
    build_state(data, adventure)
  end

  defp fetch_adventure_id(%{"adventure_id" => id}) when is_binary(id), do: {:ok, id}
  defp fetch_adventure_id(_), do: {:error, "Snapshot names no adventure"}

  defp validate_version(%{"version" => 3}), do: :ok
  defp validate_version(%{"version" => v}), do: {:error, "Unsupported version: #{v}"}
  defp validate_version(_), do: {:error, "Invalid format: missing version"}

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
    |> Enum.map(fn {scene_id, scene_data} ->
      order = scene_data["order"]

      cond do
        scene_data["custom"] == true ->
          {scene_id, build_custom_scene(scene_data, scene_id, order, adventure)}

        adventure_scene = Adventure.find_scene_by_id(adventure, scene_id) ->
          {scene_id, build_scene(scene_data, adventure_scene, order, adventure)}

        true ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp build_scene(scene_data, adventure_scene, order, adventure) do
    data =
      adventure_scene
      |> apply_uploaded_map(scene_data["custom_map"])
      |> apply_roster(scene_data["roster"])

    %State.Scene{
      id: adventure_scene.id,
      order: order,
      name: adventure_scene.name,
      uploaded_map: scene_data["uploaded_map"] == true,
      data: data,
      map: build_map(scene_data["map"] || %{}),
      tokens: build_tokens(scene_data["tokens"] || [], data, adventure),
      drawn_elements: build_drawn_elements(scene_data["drawn_elements"] || [])
    }
  end

  defp apply_uploaded_map(adventure_scene, nil), do: adventure_scene

  defp apply_uploaded_map(adventure_scene, map_data) do
    %{adventure_scene | map: restore_custom_map(map_data)}
  end

  # The blob stays the source of what it declares, so its entries come first and
  # a name it declares wins. Only what no blob supplies is taken from the snapshot.
  defp apply_roster(adventure_scene, carried) when carried in [nil, []], do: adventure_scene

  defp apply_roster(adventure_scene, carried) when is_list(carried) do
    declared = MapSet.new(adventure_scene.tokens || [], & &1.id)
    extra = carried |> Enum.map(&restore_roster_entry/1) |> Enum.reject(&is_nil/1)
    extra = Enum.reject(extra, &MapSet.member?(declared, &1.id))

    %{adventure_scene | tokens: (adventure_scene.tokens || []) ++ extra}
  end

  defp restore_roster_entry(%{"id" => id} = entry) when is_binary(id) do
    %Adventure.Scene.Token{
      id: id,
      name: entry["name"],
      owner: entry["owner"],
      image: entry["image"],
      size: entry["size"]
    }
  end

  defp restore_roster_entry(_entry), do: nil

  defp restored_roster(carried) when is_list(carried) do
    carried |> Enum.map(&restore_roster_entry/1) |> Enum.reject(&is_nil/1)
  end

  defp restored_roster(_carried), do: []

  defp build_custom_scene(scene_data, scene_id, order, adventure) do
    custom_map_data = scene_data["custom_map"]

    adventure_scene_data =
      if custom_map_data do
        map = restore_custom_map(custom_map_data)

        %AdventureScene{
          id: scene_id,
          name: scene_data["name"],
          type: "battle",
          map: map,
          tokens: restored_roster(scene_data["roster"]),
          place_tokens: []
        }
      end

    %State.Scene{
      id: scene_id,
      order: order,
      custom: true,
      uploaded_map: scene_data["uploaded_map"] == true,
      name: scene_data["name"],
      data: adventure_scene_data,
      map: build_map(scene_data["map"] || %{}),
      tokens: build_tokens(scene_data["tokens"] || [], nil, adventure),
      drawn_elements: build_drawn_elements(scene_data["drawn_elements"] || [])
    }
  end

  defp restore_custom_map(data) do
    %AdventureMap{
      width: data["width"],
      height: data["height"],
      grid_size: data["grid_size"],
      grid_line_width: data["grid_line_width"],
      show_grid: data["show_grid"],
      floors: data["floors"] || [],
      layers: Enum.map(data["layers"] || [], &restore_custom_layer/1),
      map_objects: Enum.map(data["map_objects"] || [], &restore_custom_map_object/1),
      grid: restore_custom_additional_layer(data["grid"]),
      fow: restore_custom_additional_layer(data["fow"])
    }
  end

  defp restore_custom_layer(data) do
    %AdventureLayer{
      name: data["name"],
      image: data["image"],
      images: Enum.map(data["images"] || [], &restore_sub_image/1),
      index: data["index"],
      x: data["x"],
      y: data["y"],
      width: data["width"],
      height: data["height"],
      tags: data["tags"] || [],
      show: data["show"],
      light: data["light"],
      floor: data["floor"]
    }
  end

  defp restore_sub_image(data) do
    %{
      image: data["image"],
      x: data["x"],
      y: data["y"],
      width: data["width"],
      height: data["height"]
    }
  end

  defp restore_custom_map_object(data) do
    %AdventureMapObject{
      name: data["name"],
      image: data["image"],
      x: data["x"],
      y: data["y"],
      width: data["width"],
      height: data["height"],
      layer_index: data["layer_index"],
      tags: data["tags"] || [],
      show: data["show"]
    }
  end

  defp restore_custom_additional_layer(nil), do: nil

  defp restore_custom_additional_layer(data) do
    %AdditionalLayer{
      name: data["name"],
      image: data["image"],
      x: data["x"],
      y: data["y"],
      width: data["width"],
      height: data["height"],
      tags: data["tags"] || []
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
        id: adhoc["id"] || data["data_id"],
        name: adhoc["label"],
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
        %{tokens: tokens} -> Enum.find(tokens, &(&1.id == data["data_id"]))
        _ -> nil
      end

    adventure_token =
      adventure_token ||
        Find.find_group_token(data["data_id"]) ||
        Adventure.find_token_by_id(adventure, data["data_id"])

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
