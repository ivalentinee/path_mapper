defmodule PathMapper.Adventures do
  use Agent

  defstruct [:list, :loaded]

  alias PathMapper.Adventures.Adventure
  alias Phoenix.PubSub

  @update_pubsub_topic "adventures"
  @adventure_loaded_event :adventure_loaded

  def start_link(_) do
    case read_adventure_directory() do
      {:ok, filenames} ->
        Agent.start_link(fn -> %__MODULE__{list: filenames} end, name: __MODULE__)

      error ->
        error
    end
  end

  def load_adventure(filename) when is_binary(filename) do
    filenames = Agent.get(__MODULE__, & &1).list

    if Enum.any?(filenames, &(&1 == filename)) do
      load_adventure_from_file(filename)
    else
      {:error, "Adventure file '#{filename}' not found"}
    end
  end

  def get_adventures do
    Agent.get(__MODULE__, & &1)
  end

  def subscribe do
    PubSub.subscribe(PathMapper.PubSub, @update_pubsub_topic)
  end

  defp load_adventure_from_file(filename) do
    dir_path = Application.get_env(:path_mapper, :adventure_base_path)
    full_path = Path.join(dir_path, filename)

    case Adventure.read(full_path, filename) do
      {:ok, adventure} ->
        Agent.update(__MODULE__, &Map.put(&1, :loaded, adventure))

        PubSub.broadcast(PathMapper.PubSub, @update_pubsub_topic, %{
          @adventure_loaded_event => get_adventures()
        })

        {:ok, adventure}

      error ->
        error
    end
  end

  defp read_adventure_directory do
    dir_path = Application.get_env(:path_mapper, :adventure_base_path)

    case File.ls(dir_path) do
      {:ok, filenames} -> {:ok, zip_filenames(filenames)}
      error -> error
    end
  end

  defp zip_filenames(filenames) when is_list(filenames) do
    Enum.filter(filenames, fn filename -> Path.extname(filename) == ".zip" end)
  end
end
