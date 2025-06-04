defmodule PathMapper.Adventures do
  use GenServer

  alias PathMapper.Adventures.Adventure.Scene.Map.ORAReader

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, nil}
  end

  def load_adventure(adventure_file) when is_binary(adventure_file) do
    full_path = Path.join(Application.get_env(:path_mapper, :adventure_base_path), adventure_file)
    ORAReader.read_adventure_file(full_path)
  end
end
