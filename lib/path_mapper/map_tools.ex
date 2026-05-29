defmodule PathMapper.MapTools do
  use Agent

  alias Phoenix.PubSub

  @topic "map_tools"

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def subscribe do
    PubSub.subscribe(PathMapper.PubSub, @topic)
  end

  def get_all do
    Agent.get(__MODULE__, & &1)
  end

  def draw(session_id, tool_data) do
    tool_data = Map.put(tool_data, "session_id", session_id)
    Agent.update(__MODULE__, &Map.put(&1, session_id, tool_data))
    broadcast(%{tool_update: tool_data})
  end

  def clear(session_id) do
    Agent.update(__MODULE__, &Map.delete(&1, session_id))
    broadcast(%{tool_clear: session_id})
  end

  defp broadcast(event) do
    PubSub.broadcast(PathMapper.PubSub, @topic, event)
  end
end
