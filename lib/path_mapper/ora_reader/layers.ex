defmodule PathMapper.ORAReader.Layers do
  require Logger

  alias PathMapper.ORAReader
  alias PathMapper.ORAReader.Geometry
  alias PathMapper.ORAReader.Image
  alias PathMapper.ORAReader.XML

  require Record
  Record.defrecord(:xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))

  @layer_prefix_regex ~r/\[(L)(\d+)\]/
  @special_prefix_regex ~r/\[([BGF])\]/
  @tag_regex ~r/\[([^\]]+)\]/

  def get_all_layers(document, ora_files) do
    stack_element = List.first(XML.get_children(document, :stack))
    children = XML.get_children(stack_element, :layer) ++ XML.get_children(stack_element, :stack)
    all_items = Enum.flat_map(children, &classify_element(&1, ora_files))
    {:ok, all_items}
  end

  def find_layers(all_items) do
    all_items
    |> Enum.filter(&(&1.type == :layer))
    |> Enum.sort_by(& &1.index)
  end

  def find_additional_layer(all_items, type) when type in [:grid, :fow] do
    Enum.find(all_items, &(&1.type == type))
  end

  def find_map_objects(all_items) do
    all_items
    |> Enum.filter(&(&1.type == :map_object))
    |> Enum.sort_by(& &1.layer_index)
  end

  # --- Classification ---

  defp classify_element(element, ora_files) do
    case XML.get_attribute_value(element, :name) do
      {:ok, name} -> classify_by_name(element, name, ora_files)
      _ -> []
    end
  end

  defp classify_by_name(element, name, ora_files) do
    cond do
      match = Regex.run(@layer_prefix_regex, name) ->
        [_, _, index_str] = match
        index = String.to_integer(index_str)
        tags = parse_suffix_tags(name)
        display_name = strip_prefixes_and_tags(name)

        case element_type(element) do
          :stack -> classify_group(element, index, display_name, tags, ora_files)
          :layer -> [build_flat_layer(element, index, display_name, tags, ora_files)]
        end

      match = Regex.run(@special_prefix_regex, name) ->
        [_, letter] = match
        type = special_type(letter)
        tags = parse_suffix_tags(name)
        display_name = strip_prefixes_and_tags(name)
        [build_special_layer(element, type, display_name, tags, ora_files)]

      true ->
        Logger.warning("ORA: ignoring layer with unrecognized name: #{inspect(name)}")
        []
    end
  end

  defp classify_group(stack_element, index, group_name, group_tags, ora_files) do
    children = XML.get_children(stack_element, :layer)

    {base_layers, objects} =
      Enum.reduce(children, {[], []}, &classify_group_child(&1, &2, index, ora_files))

    base_layers = Enum.reverse(base_layers)
    objects = Enum.reverse(objects)

    layer_items =
      Enum.map(base_layers, fn base ->
        %{
          type: :layer,
          name: base[:name] || group_name,
          image: base.image,
          x: base.x,
          y: base.y,
          width: base.width,
          height: base.height,
          tags: group_tags,
          index: index
        }
      end)

    # If no [B] layers found, this is a group with no base — just objects
    layer_items =
      if Enum.empty?(layer_items) do
        Logger.warning("ORA: layer group [L#{index}] has no [B] base layer")
        []
      else
        layer_items
      end

    layer_items ++ objects
  end

  defp classify_group_child(child, {bases, objs}, index, ora_files) do
    case XML.get_attribute_value(child, :name) do
      {:ok, child_name} ->
        if String.contains?(child_name, "[B]") do
          base_name = strip_prefixes_and_tags(child_name)
          base = build_image_data(child, base_name, ora_files)
          {[base | bases], objs}
        else
          obj_name = String.trim(child_name)
          obj = build_object(child, obj_name, index, ora_files)
          {bases, [obj | objs]}
        end

      _ ->
        {bases, objs}
    end
  end

  # --- Builders ---

  defp build_flat_layer(element, index, name, tags, ora_files) do
    data = build_image_data(element, name, ora_files)
    Map.merge(data, %{type: :layer, tags: tags, index: index})
  end

  defp build_special_layer(element, type, name, tags, ora_files) do
    data = build_image_data(element, name, ora_files)
    Map.merge(data, %{type: type, tags: tags})
  end

  defp build_object(element, name, layer_index, ora_files) do
    data = build_image_data(element, name, ora_files)
    Map.merge(data, %{type: :map_object, layer_index: layer_index, tags: []})
  end

  defp build_image_data(element, name, ora_files) do
    with {:ok, src} <- XML.get_attribute_value(element, :src),
         {:ok, image_file} <- ORAReader.find_ora_file(ora_files, src),
         {:ok, {x, y}} <- Geometry.get_position(element) do
      {width, height} =
        case Image.png_dimensions(image_file) do
          {:ok, dims} -> dims
          _ -> {0, 0}
        end

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

  defp strip_prefixes_and_tags(name) do
    name
    |> String.replace(@tag_regex, "")
    |> String.replace(@layer_prefix_regex, "")
    |> String.trim()
  end

  defp special_type("G"), do: :grid
  defp special_type("F"), do: :fow
  defp special_type("B"), do: :base
end
