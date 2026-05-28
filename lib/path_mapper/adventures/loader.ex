defmodule PathMapper.Adventures.Loader do
  alias Ecto.Changeset
  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.FileStorage
  alias PathMapper.Zip

  @manifest_filename "manifest.toml"

  def load(filename) when is_binary(filename) do
    dir_path = Application.get_env(:path_mapper, :adventure_base_path)
    full_path = Path.join(dir_path, filename)
    read_from_file(full_path, filename)
  end

  defp read_from_file(full_path, filename) do
    with :ok <- FileStorage.initialize(),
         {:ok, adventure_zip} <- Zip.read(full_path),
         {:ok, adventure_manifest_file} <- Zip.get_file(adventure_zip, @manifest_filename),
         {:ok, adventure_manifest} <- parse_manifest(adventure_manifest_file),
         {:ok, changeset} <- build_changeset(adventure_manifest, adventure_zip, filename),
         {:ok, adventure} <- Changeset.apply_action(changeset, :insert) do
      {:ok, adventure}
    else
      error -> error
    end
  end

  defp build_changeset(adventure_manifest, adventure_zip, filename) do
    {:ok,
     Adventure.changeset(
       %Adventure{},
       Map.put(adventure_manifest, "file", filename),
       adventure_zip
     )}
  end

  defp parse_manifest(adventure_manifest_file) do
    case :tomerl.parse(adventure_manifest_file) do
      {:ok, adventure_manifest} -> {:ok, adventure_manifest}
      {:error, error} -> {:error, {:toml_parse_error, error}}
      error -> {:error, {:toml_parse_error, error}}
    end
  end
end
