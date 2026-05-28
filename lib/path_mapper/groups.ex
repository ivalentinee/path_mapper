defmodule PathMapper.Groups do
  use Agent

  require Logger
  alias PathMapper.Groups.LoadedStorage
  alias PathMapper.Groups.Loader
  alias Phoenix.PubSub

  @update_pubsub_topic "groups"
  @group_loaded_event :group_loaded

  def start_link(_) do
    case read_group_directory() do
      {:ok, filenames} -> Agent.start_link(fn -> filenames end, name: __MODULE__)
      error -> error
    end
  end

  def get, do: Agent.get(__MODULE__, & &1)

  def subscribe do
    PubSub.subscribe(PathMapper.PubSub, @update_pubsub_topic)
  end

  def broadcast(event) do
    PubSub.broadcast(PathMapper.PubSub, @update_pubsub_topic, event)
  end

  def load_group(filename) when is_binary(filename) do
    with {:ok, filename} <- get_filename(filename),
         {:ok, group} <- Loader.load(filename),
         :ok <- LoadedStorage.store(group) do
      PathMapper.FileStorage.cleanup("group", group)
      broadcast(%{@group_loaded_event => group})
      {:ok, group}
    else
      error ->
        errors = PathMapper.Errors.format_load_error(error)
        Logger.error("Failed to load group: #{inspect(errors)}")
        broadcast(%{group_load_error: errors})
        error
    end
  end

  def reload do
    case read_group_directory() do
      {:ok, filenames} ->
        Agent.update(__MODULE__, fn _state -> filenames end)
        broadcast(%{groups_list_updated: filenames})
        :ok

      _ ->
        :ok
    end
  end

  def get_loaded, do: LoadedStorage.get()

  defp read_group_directory do
    dir_path = Application.get_env(:path_mapper, :group_base_path)

    case File.ls(dir_path) do
      {:ok, filenames} -> {:ok, keep_zip_filenames_only(filenames)}
      error -> error
    end
  end

  defp keep_zip_filenames_only(filenames) when is_list(filenames) do
    Enum.filter(filenames, fn filename -> Path.extname(filename) == ".zip" end)
  end

  defp get_filename(filename) when is_binary(filename) do
    filenames = Agent.get(__MODULE__, & &1)

    if Enum.any?(filenames, &(&1 == filename)) do
      {:ok, filename}
    else
      {:error, "Group file '#{filename}' not found"}
    end
  end
end
