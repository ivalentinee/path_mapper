defmodule PathMapper.ORAReader.Layers do
  alias PathMapper.ORAReader
  alias PathMapper.ORAReader.Geometry
  alias PathMapper.ORAReader.XML

  @name_regex ~r/(([0-9]+) - )?([^\[]+) *(\[.+\])?/
  @tag_trim_regex ~r/[ \[\]]+/
  @empty_capture ""

  def get_all_layers(element, ora_files) do
    stack_element = List.first(XML.get_children(element, :stack))
    layer_xml_elements = XML.get_children(stack_element, :layer)
    all_layers = Enum.map(layer_xml_elements, &get_layer(&1, ora_files))
    {:ok, all_layers}
  end

  def find_layers(all_layers) do
    all_layers
    |> Enum.filter(fn %{type: type} -> type == :layer end)
    |> Enum.sort_by(fn %{index: index} -> index end)
  end

  def find_additional_layer(all_layers, name) do
    Enum.find(all_layers, fn
      %{name: layer_name, type: type} -> type == :additional_layer && layer_name == name
      _ -> false
    end)
  end

  defp get_layer(layer_xml_element, ora_files) do
    with {:ok, image} <- XML.get_attribute_value(layer_xml_element, :src),
         {:ok, image_file} <- ORAReader.find_ora_file(ora_files, image),
         {:ok, name} <- XML.get_attribute_value(layer_xml_element, :name),
         {:ok, {parsed_name, index, tags}} <- parse_name(name),
         {:ok, {x, y}} <- Geometry.get_position(layer_xml_element) do
      if index,
        do: build_layer(:layer, parsed_name, image_file, x, y, tags, index),
        else: build_layer(:additional_layer, parsed_name, image_file, x, y, tags)
    else
      error -> error
    end
  end

  defp parse_name(full_name) do
    case Regex.run(@name_regex, full_name) do
      [_, _, @empty_capture, name] ->
        {:ok, {String.trim(name), nil, nil}}

      [_, _, @empty_capture, name, tags] ->
        {:ok, {String.trim(name), nil, parse_tags(tags)}}

      [_, _, index, name] ->
        {:ok, {String.trim(name), String.to_integer(index), []}}

      [_, _, index, name, tags] ->
        {:ok, {String.trim(name), String.to_integer(index), parse_tags(tags)}}
    end
  end

  defp parse_tags(tag_string) do
    tag_string
    |> String.replace(@tag_trim_regex, "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp build_layer(type, name, image, x, y, tags, index \\ nil) when is_atom(type) do
    %{type: type, name: name, image: image, x: x, y: y, tags: tags, index: index}
  end
end
