defmodule PathMapper.Adventures.Adventure.FileStorage do
  alias Ecto.Changeset
  alias PathMapper.Zip

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

  def store_image(%Changeset{} = changeset, property) do
    with image when is_binary(image) <- Changeset.get_change(changeset, property),
         {:ok, filename} <- store_image(image) do
      Changeset.put_change(changeset, property, filename)
    else
      _ -> Changeset.put_change(changeset, property, nil)
    end
  end

  def store_image_from_zip(%Changeset{} = changeset, property, zip_file) do
    with zip_filename when is_binary(zip_filename) <- Changeset.get_change(changeset, property),
         {:ok, image} <- Zip.get_file(zip_file, zip_filename),
         {:ok, filename} <- store_image(image) do
      Changeset.put_change(changeset, property, filename)
    else
      _ -> Changeset.put_change(changeset, property, nil)
    end
  end

  defp random_name do
    to_string(round(:rand.uniform() * 10_000_100))
  end
end
