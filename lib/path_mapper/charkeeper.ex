defmodule PathMapper.Charkeeper do
  @moduledoc false

  alias __MODULE__.Poller
  alias Phoenix.PubSub

  @topic "charkeeper"

  def subscribe do
    PubSub.subscribe(PathMapper.PubSub, @topic)
  end

  def broadcast(payload) do
    PubSub.broadcast(PathMapper.PubSub, @topic, %{charkeeper_update: payload})
  end

  def get_data do
    case Poller.whereis() do
      nil -> %{data: %{}, status: nil}
      pid -> GenServer.call(pid, :get_data)
    end
  end

  def start_or_restart(players) do
    ids = extract_charkeeper_ids(players)

    case ids do
      [] -> stop()
      ids -> do_start(ids)
    end
  end

  def stop do
    case Poller.whereis() do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(__MODULE__.Supervisor, pid)
    end

    broadcast(%{data: %{}, status: nil})
  end

  defp extract_charkeeper_ids(players) do
    players
    |> Enum.filter(& &1.charkeeper_id)
    |> Enum.map(&{&1.character_name, &1.charkeeper_id})
  end

  defp do_start(ids) do
    stop()

    DynamicSupervisor.start_child(
      __MODULE__.Supervisor,
      {Poller, ids}
    )
  end
end
