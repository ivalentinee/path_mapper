defmodule PathMapper.FileStorage do
  alias Ecto.Changeset
  alias PathMapper.Zip

  @public_directory "static"
  @image_extension "png"

  def initialize(subdirectory) do
    path = storage_directory_path(subdirectory)

    with {:ok, _} <- File.rm_rf(path),
         :ok <- File.mkdir(path) do
      :ok
    else
      _error -> {:error, "Failed to initialize #{subdirectory} file storage"}
    end
  end

  def store_image(file, subdirectory) when is_binary(file),
    do: store(file, @image_extension, subdirectory)

  def store(file, extension, subdirectory)
      when is_binary(file) and is_binary(extension) do
    filename = "#{random_name()}.#{extension}"

    case File.write(Path.join(storage_directory_path(subdirectory), filename), file) do
      :ok -> {:ok, Path.join(["/", subdirectory, filename])}
      error -> error
    end
  end

  def store_image(%Changeset{} = changeset, property, subdirectory) do
    with image when is_binary(image) <- Changeset.get_change(changeset, property),
         {:ok, filename} <- store_image(image, subdirectory) do
      Changeset.put_change(changeset, property, filename)
    else
      _ -> Changeset.put_change(changeset, property, nil)
    end
  end

  def store_image_from_zip(%Changeset{} = changeset, property, zip_file, subdirectory) do
    with zip_filename when is_binary(zip_filename) <- Changeset.get_change(changeset, property),
         {:ok, image} <- Zip.get_file(zip_file, zip_filename),
         {:ok, filename} <- store_image(image, subdirectory) do
      Changeset.put_change(changeset, property, filename)
    else
      _ -> Changeset.put_change(changeset, property, nil)
    end
  end

  defp random_name do
    to_string(round(:rand.uniform() * 10_000_100))
  end

  defp storage_directory_path(subdirectory) do
    Path.join([:code.priv_dir(:path_mapper), @public_directory, subdirectory])
  end
end
