defmodule PathMapper.Adventures.Adventure.FileStorage do
  alias Ecto.Changeset

  @subdirectory "adventure"

  def initialize, do: PathMapper.FileStorage.initialize(@subdirectory)

  def store_image(file) when is_binary(file),
    do: PathMapper.FileStorage.store_image(file, @subdirectory)

  def store(file, extension) when is_binary(file) and is_binary(extension),
    do: PathMapper.FileStorage.store(file, extension, @subdirectory)

  def store_image(%Changeset{} = changeset, property),
    do: PathMapper.FileStorage.store_image(changeset, property, @subdirectory)

  def store_image_from_zip(%Changeset{} = changeset, property, zip_file),
    do: PathMapper.FileStorage.store_image_from_zip(changeset, property, zip_file, @subdirectory)
end
