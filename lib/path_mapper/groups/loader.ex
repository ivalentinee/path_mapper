defmodule PathMapper.Groups.Loader do
  alias Ecto.Changeset
  alias PathMapper.Groups.Group
  alias PathMapper.Groups.Group.FileStorage
  alias PathMapper.Zip

  @manifest_filename "manifest.toml"

  def load(filename) when is_binary(filename) do
    dir_path = Application.get_env(:path_mapper, :group_base_path)
    full_path = Path.join(dir_path, filename)
    read_from_file(full_path, filename)
  end

  defp read_from_file(full_path, filename) do
    with :ok <- FileStorage.initialize(),
         {:ok, group_zip} <- Zip.read(full_path),
         {:ok, group_manifest_file} <- Zip.get_file(group_zip, @manifest_filename),
         {:ok, group_manifest} <- parse_manifest(group_manifest_file),
         {:ok, changeset} <- build_changeset(group_manifest, group_zip, filename),
         {:ok, group} <- Changeset.apply_action(changeset, :insert) do
      {:ok, group}
    else
      error -> error
    end
  end

  defp parse_manifest(group_manifest_file) do
    case :tomerl.parse(group_manifest_file) do
      {:ok, group_manifest} -> {:ok, group_manifest}
      {:error, error} -> {:error, {:toml_parse_error, error}}
      error -> {:error, {:toml_parse_error, error}}
    end
  end

  defp build_changeset(group_manifest, group_zip, filename) do
    {:ok,
     Group.changeset(
       %Group{},
       Map.put(group_manifest, "file", filename),
       group_zip
     )}
  end
end
