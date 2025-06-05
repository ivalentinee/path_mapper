defmodule PathMapper.Game do
  use Agent

  alias __MODULE__.State
  alias PathMapper.Adventures
  alias PathMapper.Adventures.Adventure
  alias Phoenix.PubSub

  @update_pubsub_topic "game"

  def subscribe do
    PubSub.subscribe(PathMapper.PubSub, @update_pubsub_topic)
  end

  def broadcast(event) do
    PubSub.broadcast(PathMapper.PubSub, @update_pubsub_topic, event)
  end

  def start_link(_) do
    Agent.start_link(fn -> %State{} end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, & &1)
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> %State{} end)
    broadcast_game_update()
  end

  def select_scene(index) when is_number(index) do
    case Adventures.get_loaded_adventure() do
      {:ok, %Adventure{scenes: scenes} = adventure} ->
        select_scene(adventure, Enum.at(scenes, index).name)

      error ->
        error
    end
  end

  def select_scene(name) when is_binary(name) do
    case Adventures.get_loaded_adventure() do
      {:ok, adventure} -> select_scene(adventure, name)
      error -> error
    end
  end

  def select_scene(%Adventure{scenes: scenes}, scene_name) when is_binary(scene_name) do
    if Enum.find(scenes, &(&1.name == scene_name)) do
      Agent.update(__MODULE__, &Map.put(&1, :scene, scene_name))
      broadcast_game_update()
    end
  end

  defp broadcast_game_update, do: broadcast(%{game_update: get()})
end
