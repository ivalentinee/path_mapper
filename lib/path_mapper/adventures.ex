defmodule PathMapper.Adventures do
  use Agent

  require Logger
  alias Ecto.Changeset
  alias PathMapper.Adventures.LoadedStorage
  alias PathMapper.Adventures.Loader
  alias Phoenix.PubSub

  @update_pubsub_topic "adventures"
  @adventure_loaded_event :adventure_loaded

  def start_link(_) do
    case read_adventure_directory() do
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

  def load_adventure(filename) when is_binary(filename) do
    with {:ok, filename} <- get_filename(filename),
         {:ok, adventure} <- Loader.load(filename),
         :ok <- LoadedStorage.store(adventure) do
      broadcast(%{@adventure_loaded_event => adventure})
      {:ok, adventure}
    else
      {:error, %Changeset{} = changeset} ->
        Logger.error(
          "Failed to load adventure: #{inspect(PathMapper.Errors.display_errors(changeset))}"
        )

        {:error, changeset}

      error ->
        Logger.error("Failed to load adventure: #{inspect(error)}")
        error
    end
  end

  def get_loaded, do: LoadedStorage.get()

  defp read_adventure_directory do
    dir_path = Application.get_env(:path_mapper, :adventure_base_path)

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
      {:error, "Adventure file '#{filename}' not found"}
    end
  end
end
