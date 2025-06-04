defmodule PathMapper.Zip do
  @enforce_keys [:entries, :filename]
  defstruct [:entries, :filename]

  def read(filename) when is_binary(filename) do
    case :zip.unzip(to_charlist(filename), [:memory]) do
      {:ok, entries} -> {:ok, %__MODULE__{entries: entries, filename: filename}}
      error -> error
    end
  end

  def get_file(%__MODULE__{entries: entries, filename: zip_filename}, filename)
      when is_binary(filename) do
    case Enum.find(entries, fn {entry_name, _file} -> entry_name == to_charlist(filename) end) do
      {_filename, file} -> {:ok, file}
      _ -> {:error, "Zip file '#{zip_filename}' entry '#{filename}' not found"}
    end
  end
end
