defmodule PathMapper.CustomFileStorage do
  @moduledoc false

  @subdirectory "custom"

  def initialize, do: PathMapper.FileStorage.initialize(@subdirectory)

  def store_image(file) when is_binary(file),
    do: PathMapper.FileStorage.store_image(file, @subdirectory)

  def cleanup(data), do: PathMapper.FileStorage.cleanup(@subdirectory, data)
end
