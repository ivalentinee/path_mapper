defmodule PathMapper.Groups.Group.FileStorage do
  alias Ecto.Changeset

  @subdirectory "group"

  def initialize, do: PathMapper.FileStorage.initialize(@subdirectory)

  def store_image(file) when is_binary(file),
    do: PathMapper.FileStorage.store_image(file, @subdirectory)

  def store(file, extension) when is_binary(file) and is_binary(extension),
    do: PathMapper.FileStorage.store(file, extension, @subdirectory)

  def store_image_from_zip(%Changeset{} = changeset, property, zip_file),
    do: PathMapper.FileStorage.store_image_from_zip(changeset, property, zip_file, @subdirectory)
end
