defmodule PathMapper.FileStorage do
  alias Ecto.Changeset
  alias PathMapper.Zip

  @public_directory "unpacked"
  @image_extension "png"

  def initialize(subdirectory) do
    case File.mkdir_p(storage_directory_path(subdirectory)) do
      :ok -> :ok
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
      nil ->
        changeset

      {:error, reason} ->
        Changeset.add_error(changeset, property, "failed to store image: %{reason}",
          reason: inspect(reason),
          validation: :file_storage
        )
    end
  end

  def store_image_from_zip(%Changeset{} = changeset, property, zip_file, subdirectory) do
    with zip_filename when is_binary(zip_filename) <- Changeset.get_change(changeset, property),
         {:ok, image} <- Zip.get_file(zip_file, zip_filename),
         {:ok, filename} <- store_image(image, subdirectory) do
      Changeset.put_change(changeset, property, filename)
    else
      nil ->
        changeset

      {:error, reason} ->
        Changeset.add_error(changeset, property, "failed to load file: %{reason}",
          reason: inspect(reason),
          validation: :file_storage
        )
    end
  end

  def cleanup(subdirectory, data) do
    dir = storage_directory_path(subdirectory)
    prefix = "/#{subdirectory}/"

    keep =
      data
      |> collect_paths(prefix)
      |> MapSet.new(&Path.basename/1)

    with {:ok, files} <- File.ls(dir) do
      files
      |> Enum.reject(&MapSet.member?(keep, &1))
      |> Enum.each(&File.rm(Path.join(dir, &1)))
    end
  end

  defp collect_paths(value, prefix) when is_binary(value) do
    if String.starts_with?(value, prefix), do: [value], else: []
  end

  defp collect_paths(%{__struct__: _} = struct, prefix) do
    struct |> Map.from_struct() |> collect_paths(prefix)
  end

  defp collect_paths(map, prefix) when is_map(map) do
    Enum.flat_map(Map.values(map), &collect_paths(&1, prefix))
  end

  defp collect_paths(list, prefix) when is_list(list) do
    Enum.flat_map(list, &collect_paths(&1, prefix))
  end

  defp collect_paths(_, _), do: []

  defp random_name do
    to_string(round(:rand.uniform() * 10_000_100))
  end

  defp storage_directory_path(subdirectory) do
    Path.join([:code.priv_dir(:path_mapper), @public_directory, subdirectory])
  end
end
