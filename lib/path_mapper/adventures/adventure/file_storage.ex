defmodule PathMapper.Adventures.Adventure.FileStorage do
  @public_directory "priv/static"
  @adventure_directory "adventure"
  @storage_directory Path.join(@public_directory, @adventure_directory)
  @image_extension "png"

  def initialize do
    with {:ok, _} <- File.rm_rf(@storage_directory),
         :ok <- File.mkdir(@storage_directory) do
      :ok
    else
      _error -> {:error, "Failed to initialize adventure file storage"}
    end
  end

  def store_image(file) when is_binary(file), do: store(file, @image_extension)

  def store(file, extension) when is_binary(file) and is_binary(extension) do
    filename = "#{random_name()}.#{extension}"

    case File.write(Path.join(@storage_directory, filename), file) do
      :ok -> {:ok, Path.join(["/", @adventure_directory, filename])}
      error -> error
    end
  end

  defp random_name do
    to_string(round(:rand.uniform() * 10_000_100))
  end
end
