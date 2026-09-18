defmodule PathMapper.Game.Snapshot do
  @moduledoc false

  alias PathMapper.AssetSource
  alias PathMapper.FileStorage
  alias PathMapper.UploadStorage

  require Logger

  @manifest "manifest.json"
  @asset_dir "assets"

  def pack(manifest) when is_map(manifest) do
    entries =
      [{to_charlist(@manifest), Jason.encode!(manifest)} | asset_entries(manifest)]

    case :zip.create(~c"snapshot.zip", entries, [:memory]) do
      {:ok, {_name, binary}} -> {:ok, binary}
      {:error, reason} -> {:error, {:zip, reason}}
    end
  end

  def unpack(binary) when is_binary(binary) do
    with :ok <- UploadStorage.initialize(),
         {:ok, entries} <- unzip(binary),
         {:ok, manifest_json} <- fetch(entries, @manifest),
         {:ok, manifest} <- decode(manifest_json) do
      entries |> Enum.each(&restore_asset/1)
      {:ok, manifest}
    end
  end

  defp asset_entries(manifest) do
    manifest
    |> FileStorage.referenced_paths(AssetSource.upload())
    |> Enum.flat_map(&asset_entry/1)
  end

  defp asset_entry(path) do
    case FileStorage.read_stored(path) do
      {:ok, bytes} ->
        [{to_charlist(Path.join(@asset_dir, Path.basename(path))), bytes}]

      {:error, reason} ->
        Logger.warning("Snapshot skipped #{path}: #{inspect(reason)}")
        []
    end
  end

  defp restore_asset({name, bytes}) do
    name = to_string(name)

    if Path.dirname(name) == @asset_dir do
      case UploadStorage.store_image(bytes) do
        {:ok, _path} -> :ok
        error -> Logger.warning("Snapshot could not restore #{name}: #{inspect(error)}")
      end
    end
  end

  defp unzip(binary) do
    case :zip.unzip(binary, [:memory]) do
      {:ok, entries} -> {:ok, entries}
      _ -> {:error, "Snapshot is not a readable archive"}
    end
  end

  defp fetch(entries, name) do
    case Enum.find(entries, fn {entry, _} -> to_string(entry) == name end) do
      {_, contents} -> {:ok, contents}
      nil -> {:error, "Snapshot holds no #{name}"}
    end
  end

  defp decode(json) do
    case Jason.decode(json) do
      {:ok, manifest} -> {:ok, manifest}
      {:error, _} -> {:error, "Snapshot manifest is not valid JSON"}
    end
  end
end
