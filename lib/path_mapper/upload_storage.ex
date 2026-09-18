defmodule PathMapper.UploadStorage do
  @moduledoc false

  alias PathMapper.AssetSource
  alias PathMapper.FileStorage

  def initialize, do: FileStorage.initialize(AssetSource.upload())

  def store_image(file) when is_binary(file),
    do: FileStorage.store_image(file, AssetSource.upload())

  def store_image(%Ecto.Changeset{} = changeset, property),
    do: FileStorage.store_image(changeset, property, AssetSource.upload())

  def store(file, extension) when is_binary(file) and is_binary(extension),
    do: FileStorage.store(file, extension, AssetSource.upload())

  def cleanup(data), do: FileStorage.cleanup(AssetSource.upload(), data)

  @doc """
  Removes every stored asset.

  Distinct from `cleanup/1`, which removes only what a given structure does not
  reference. Called at application start and at reset, and nowhere else: those two
  moments are what bound the store, in place of an eviction policy.
  """
  def clear do
    with :ok <- initialize() do
      FileStorage.clear(AssetSource.upload())
    end
  end
end
