defmodule PathMapper.ORAReader.Layers do
  require Logger

  alias PathMapper.ORAReader
  alias PathMapper.ORAReader.Geometry
  alias PathMapper.ORAReader.Image
  alias PathMapper.ORAReader.XML

  require Record
  Record.defrecord(:xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))

  @layer_prefix_regex ~r/\[(L)(\d+)\]/
  @special_prefix_regex ~r/\[([GFM])\]/
  @tag_regex ~r/\[([^\]]+)\]/

  def get_all_layers(document, ora_files) do
    stack_element = List.first(XML.get_children(document, :stack))
    origin = stack_origin(stack_element)
    children = XML.get_children(stack_element, :layer) ++ XML.get_children(stack_element, :stack)
    all_items = Enum.flat_map(children, &classify_element(&1, origin, ora_files))
    {:ok, all_items}
  end

  # OpenRaster places a stack's children relative to the stack itself, so a
  # group carrying an offset of its own puts everything inside it that far from
  # where this used to read it. A stack with no x/y is at the origin, which is
  # what our own hand-written fixtures say and why no test saw this.
  defp stack_origin(element) do
    case Geometry.get_position(element) do
      {:ok, position} -> position
      _error -> {0, 0}
    end
  end

  defp translate({x, y}, {dx, dy}), do: {x + dx, y + dy}

  def find_layers(all_items) do
    all_items
    |> Enum.filter(&(&1.type == :layer))
    |> Enum.sort_by(& &1.index)
  end

  def find_additional_layer(all_items, type) when type in [:grid, :fow] do
    Enum.find(all_items, &(&1.type == type))
  end

  @doc "The map's metadata layer, if it declares one."
  def find_metadata(all_items), do: Enum.find(all_items, &(&1.type == :metadata))

  def find_map_objects(all_items) do
    all_items
    |> Enum.filter(&(&1.type == :map_object))
    |> Enum.sort_by(& &1.layer_index)
  end

  # --- Classification ---

  defp classify_element(element, origin, ora_files) do
    case XML.get_attribute_value(element, :name) do
      {:ok, name} -> classify_by_name(element, origin, name, ora_files)
      _ -> []
    end
  end

  defp classify_by_name(element, origin, name, ora_files) do
    cond do
      match = Regex.run(@layer_prefix_regex, name) ->
        [_, _, index_str] = match
        index = String.to_integer(index_str)
        tags = parse_suffix_tags(name)
        display_name = strip_prefixes_and_tags(name)

        case element_type(element) do
          :stack -> classify_group(element, origin, index, display_name, tags, ora_files)
          :layer -> [build_flat_layer(element, origin, index, display_name, tags, ora_files)]
        end

      match = Regex.run(@special_prefix_regex, name) ->
        [_, letter] = match
        type = special_type(letter)
        tags = parse_suffix_tags(name)
        display_name = strip_prefixes_and_tags(name)
        [build_special(element, origin, type, display_name, tags, ora_files)]

      true ->
        Logger.warning("ORA: ignoring layer with unrecognized name: #{inspect(name)}")
        []
    end
  end

  defp classify_group(stack_element, origin, index, group_name, group_tags, ora_files) do
    inside = translate(origin, stack_origin(stack_element))
    children = XML.get_children(stack_element, :layer)

    {base_layers, objects} =
      Enum.reduce(children, {[], []}, &classify_group_child(&1, &2, {inside, index}, ora_files))

    base_layers = Enum.reverse(base_layers)
    objects = Enum.reverse(objects)

    images =
      Enum.map(base_layers, fn b ->
        %{image: b.image, x: b.x, y: b.y, width: b.width, height: b.height}
      end)

    # Use the first [B] layer's geometry for the layer itself, or zeros for object-only layers
    {layer_x, layer_y, layer_w, layer_h} =
      case base_layers do
        [first | _] -> {first.x, first.y, first.width, first.height}
        [] -> {0, 0, 0, 0}
      end

    layer_item = %{
      type: :layer,
      name: group_name,
      image: if(base_layers != [], do: List.first(base_layers).image),
      images: images,
      x: layer_x,
      y: layer_y,
      width: layer_w,
      height: layer_h,
      tags: group_tags,
      index: index
    }

    [layer_item | objects]
  end

  defp classify_group_child(child, {bases, objs}, {origin, index}, ora_files) do
    case XML.get_attribute_value(child, :name) do
      {:ok, child_name} ->
        if String.contains?(child_name, "[B]") do
          base_name = strip_prefixes_and_tags(child_name)
          base = build_image_data(child, base_name, ora_files, origin)
          {[base | bases], objs}
        else
          obj_tags = parse_all_tags(child_name)
          obj_name = strip_prefixes_and_tags(child_name)
          obj = build_object(child, origin, obj_name, index, obj_tags, ora_files)
          {bases, [obj | objs]}
        end

      _ ->
        {bases, objs}
    end
  end

  # --- Builders ---

  defp build_flat_layer(element, origin, index, name, tags, ora_files) do
    data = build_image_data(element, name, ora_files, origin)
    Map.merge(data, %{type: :layer, tags: tags, index: index})
  end

  # A metadata layer carries words, so it is built without the image data every
  # other kind needs. Having no image is what keeps it out of every rendering:
  # find_layers/1, find_additional_layer/2 and find_map_objects/1 each select a
  # type that is not this one, and there is nothing here for a template to draw.
  defp build_special(_element, _origin, :metadata, name, tags, _ora_files),
    do: %{type: :metadata, name: name, tags: tags}

  defp build_special(element, origin, type, name, tags, ora_files),
    do: build_special_layer(element, origin, type, name, tags, ora_files)

  defp build_special_layer(element, origin, type, name, tags, ora_files) do
    data = build_image_data(element, name, ora_files, origin)
    Map.merge(data, %{type: type, tags: tags})
  end

  defp build_object(element, origin, name, layer_index, tags, ora_files) do
    data = build_image_data(element, name, ora_files, origin)
    Map.merge(data, %{type: :map_object, layer_index: layer_index, tags: tags})
  end

  defp build_image_data(element, name, ora_files, origin) do
    with {:ok, src} <- XML.get_attribute_value(element, :src),
         {:ok, image_file} <- ORAReader.find_ora_file(ora_files, src),
         {:ok, position} <- Geometry.get_position(element) do
      {width, height} =
        case Image.png_dimensions(image_file) do
          {:ok, dims} -> dims
          _ -> {0, 0}
        end

      {x, y} = translate(position, origin)

      %{name: name, image: image_file, x: x, y: y, width: width, height: height}
    else
      _ -> %{name: name, image: nil, x: 0, y: 0, width: 0, height: 0}
    end
  end

  # --- Parsing helpers ---

  defp element_type(element) do
    case xmlElement(element, :name) do
      :stack -> :stack
      _ -> :layer
    end
  end

  defp parse_suffix_tags(name) do
    # Find all [X] groups, skip the first one (the prefix)
    all_matches = Regex.scan(@tag_regex, name)

    case all_matches do
      [_prefix | rest] -> Enum.map(rest, fn [_, tag] -> String.trim(tag) end)
      _ -> []
    end
  end

  defp parse_all_tags(name) do
    # Find all [X] groups — no prefix to skip (used for objects)
    @tag_regex
    |> Regex.scan(name)
    |> Enum.map(fn [_, tag] -> String.trim(tag) end)
  end

  defp strip_prefixes_and_tags(name) do
    name
    |> String.replace(@tag_regex, "")
    |> String.replace(@layer_prefix_regex, "")
    |> String.trim()
  end

  defp special_type("G"), do: :grid
  defp special_type("F"), do: :fow
  defp special_type("M"), do: :metadata
end
