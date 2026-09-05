defmodule PathMapper.CustomMapBuilder do
  @moduledoc false

  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap
  alias PathMapper.Adventures.Adventure.Scene.Map.AdditionalLayer
  alias PathMapper.Adventures.Adventure.Scene.Map.Layer
  alias PathMapper.Adventures.Adventure.Scene.Map.MapObject
  alias PathMapper.CustomFileStorage

  @default_grid_size 50
  @grid_tag_regex ~r/grid-([0-9]+)/
  @grid_line_tag_regex ~r/grid-line-([0-9]+)/
  @floor_regex ~r/^floor-([0-9]+)$/

  def build(ora_data) do
    with {:ok, layers} <- build_layers(ora_data.layers),
         {:ok, map_objects} <- build_map_objects(ora_data.map_objects),
         {:ok, grid} <- build_additional_layer(ora_data.grid),
         {:ok, fow} <- build_additional_layer(ora_data.fow) do
      all_tags = collect_all_tags(layers, grid, fow)

      map = %AdventureMap{
        width: ora_data.width,
        height: ora_data.height,
        grid_size: extract_grid_size(all_tags),
        grid_line_width: extract_grid_line_width(all_tags),
        show_grid: extract_show_grid(all_tags),
        floors: compute_floors(layers),
        layers: layers,
        map_objects: map_objects,
        grid: grid,
        fow: fow
      }

      {:ok, map}
    end
  end

  defp build_layers(layers) do
    layers
    |> Enum.reduce_while([], fn layer_data, acc ->
      case store_layer_images(layer_data) do
        {:ok, built} -> {:cont, [built | acc]}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err -> err
      layers -> {:ok, Enum.reverse(layers)}
    end
  end

  defp store_layer_images(layer_data) do
    tags = layer_data[:tags] || []

    with {:ok, image_path} <- store_image_if_present(layer_data[:image]),
         {:ok, images} <- store_sub_images(layer_data[:images] || []) do
      {:ok,
       %Layer{
         name: layer_data.name,
         image: image_path,
         images: images,
         index: layer_data.index,
         x: layer_data.x,
         y: layer_data.y,
         width: layer_data.width,
         height: layer_data.height,
         tags: tags,
         show: !Enum.member?(tags, "hide"),
         light: if(Enum.member?(tags, "dim"), do: "dim", else: "bright"),
         floor: extract_floor(tags)
       }}
    end
  end

  defp store_sub_images(images) do
    images
    |> Enum.reduce_while([], fn img, acc ->
      case store_image_if_present(img[:image] || img.image) do
        {:ok, path} ->
          stored = %{image: path, x: img.x, y: img.y, width: img.width, height: img.height}
          {:cont, [stored | acc]}

        {:error, _} = err ->
          {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err -> err
      images -> {:ok, Enum.reverse(images)}
    end
  end

  defp build_map_objects(objects) do
    objects
    |> Enum.with_index()
    |> Enum.reduce_while([], fn {obj_data, _idx}, acc ->
      tags = obj_data[:tags] || []

      case store_image_if_present(obj_data[:image] || obj_data.image) do
        {:ok, image_path} ->
          obj = %MapObject{
            name: obj_data.name,
            image: image_path,
            x: obj_data.x,
            y: obj_data.y,
            width: obj_data.width,
            height: obj_data.height,
            layer_index: obj_data.layer_index,
            tags: tags,
            show: !Enum.member?(tags, "hide")
          }

          {:cont, [obj | acc]}

        {:error, _} = err ->
          {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err -> err
      objects -> {:ok, Enum.reverse(objects)}
    end
  end

  defp build_additional_layer(nil), do: {:ok, nil}

  defp build_additional_layer(layer_data) do
    tags = layer_data[:tags] || []

    case store_image_if_present(layer_data[:image] || layer_data.image) do
      {:ok, image_path} ->
        {:ok,
         %AdditionalLayer{
           name: layer_data.name,
           image: image_path,
           x: layer_data.x,
           y: layer_data.y,
           width: layer_data.width,
           height: layer_data.height,
           tags: tags
         }}

      {:error, _} = err ->
        err
    end
  end

  defp store_image_if_present(nil), do: {:ok, nil}

  defp store_image_if_present(image) when is_binary(image) do
    CustomFileStorage.store_image(image)
  end

  defp collect_all_tags(layers, grid, fow) do
    layer_tags = Enum.flat_map(layers, fn l -> l.tags || [] end)
    grid_tags = if grid, do: grid.tags || [], else: []
    fow_tags = if fow, do: fow.tags || [], else: []
    layer_tags ++ grid_tags ++ fow_tags
  end

  defp extract_grid_size(all_tags) do
    case Enum.find_value(all_tags, &Regex.run(@grid_tag_regex, &1)) do
      [_, size_str] ->
        case Integer.parse(size_str) do
          {size, _} -> size
          :error -> @default_grid_size
        end

      _ ->
        @default_grid_size
    end
  end

  defp extract_grid_line_width(all_tags) do
    case Enum.find_value(all_tags, &Regex.run(@grid_line_tag_regex, &1)) do
      [_, width_str] ->
        case Integer.parse(width_str) do
          {width, _} -> width
          :error -> 1
        end

      _ ->
        1
    end
  end

  defp extract_show_grid(all_tags) do
    !Enum.member?(all_tags, "grid-hide")
  end

  defp extract_floor(tags) do
    case Enum.find_value(tags, &Regex.run(@floor_regex, &1)) do
      [_, floor_str] -> String.to_integer(floor_str)
      _ -> nil
    end
  end

  defp compute_floors(layers) do
    layers
    |> Enum.map(& &1.floor)
    |> Enum.uniq()
    |> Enum.filter(&is_number/1)
    |> Enum.sort()
  end
end
