defmodule PathMapper.Adventures.Adventure.Scene.Map.ORAReader do
  alias PathMapper.Adventures.Adventure.Scene.Map
  alias __MODULE__.Geometry
  alias __MODULE__.Layers

  @tmp_file_path "/tmp/tmp.xml"

  def read_adventure_file(filename) when is_binary(filename) do
    with {:ok, ora_files} <- :zip.unzip(to_charlist(filename), [:memory]),
         {:ok, stack_file} <- find_ora_file(ora_files, "stack.xml"),
         :ok <- File.write(@tmp_file_path, stack_file),
         {document, _rest} <- :xmerl_scan.file(~c"/tmp/tmp.xml"),
         :ok <- File.rm(@tmp_file_path),
         {:ok, {width, height}} <- Geometry.get_dimensions(document),
         {:ok, all_layers} <- Layers.get_all_layers(document, ora_files) do
      layers = Layers.find_layers(all_layers)
      fow = Layers.find_additional_layer(all_layers, "fow")
      {:ok, %Map{layers: layers, fow: fow, width: width, height: height}}
    else
      error -> error
    end
  end

  def find_ora_file(ora_files, name) when is_list(ora_files) and is_binary(name) do
    case Enum.find(ora_files, fn {filename, _file} -> filename == to_charlist(name) end) do
      {_filename, file} -> {:ok, file}
      _ -> {:error, "ORA file '#{name}' is missing"}
    end
  end
end
