defmodule PathMapper.ORAReader do
  alias __MODULE__.Geometry
  alias __MODULE__.Layers

  def read_from_file(file) when is_binary(file) do
    tmp_file_path =
      Path.join(System.tmp_dir!(), "ora_stack_#{:erlang.unique_integer([:positive])}.xml")

    with {:ok, ora_files} <- :zip.unzip(file, [:memory]),
         {:ok, stack_file} <- find_ora_file(ora_files, "stack.xml"),
         :ok <- File.write(tmp_file_path, stack_file),
         {document, _rest} <- :xmerl_scan.file(String.to_charlist(tmp_file_path)),
         :ok <- File.rm(tmp_file_path),
         {:ok, {width, height}} <- Geometry.get_dimensions(document),
         {:ok, all_items} <- Layers.get_all_layers(document, ora_files) do
      layers = Layers.find_layers(all_items)
      grid = Layers.find_additional_layer(all_items, :grid)
      fow = Layers.find_additional_layer(all_items, :fow)
      map_objects = Layers.find_map_objects(all_items)
      metadata = Layers.find_metadata(all_items)

      {:ok,
       %{
         layers: layers,
         grid: grid,
         fow: fow,
         map_objects: map_objects,
         width: width,
         height: height,
         name: metadata_name(metadata),
         url: metadata_url(metadata)
       }}
    else
      error -> error
    end
  end

  @url_tag_regex ~r/\Aurl\s+(\S+)\z/

  defp metadata_name(nil), do: nil
  defp metadata_name(%{name: name}), do: presence(name)

  defp metadata_url(nil), do: nil

  defp metadata_url(%{tags: tags}) do
    Enum.find_value(tags, fn tag ->
      case Regex.run(@url_tag_regex, tag) do
        [_, url] -> url
        _ -> nil
      end
    end)
  end

  defp presence(""), do: nil
  defp presence(value), do: value

  def find_ora_file(ora_files, name) when is_list(ora_files) and is_binary(name) do
    case Enum.find(ora_files, fn {filename, _file} -> filename == to_charlist(name) end) do
      {_filename, file} -> {:ok, file}
      _ -> {:error, "ORA file '#{name}' is missing"}
    end
  end
end
