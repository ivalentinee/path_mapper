defmodule PathMapper.Charkeeper.Poller do
  @moduledoc false

  use GenServer

  require Logger

  alias PathMapper.Charkeeper
  alias PathMapper.Charkeeper.Client

  @default_interval 10_000

  def start_link(ids) do
    GenServer.start_link(__MODULE__, ids, name: __MODULE__)
  end

  def whereis, do: GenServer.whereis(__MODULE__)

  @impl true
  def init(ids) do
    interval = Application.get_env(:path_mapper, :charkeeper_poll_interval, @default_interval)
    server = Application.get_env(:path_mapper, :charkeeper_server, "charkeeper.ru")

    state = %{
      ids: ids,
      interval: interval,
      server: server,
      data: %{},
      status: nil,
      generation: 0
    }

    send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, %{generation: gen} = state) do
    new_gen = gen + 1
    parent = self()
    ids = state.ids
    server = state.server
    expected = length(ids)

    Task.start(fn ->
      results = fetch_all(ids, server)

      status =
        cond do
          map_size(results) == expected -> :ok
          map_size(results) > 0 -> :partial
          true -> :error
        end

      send(parent, {:poll_result, new_gen, results, status})
    end)

    Process.send_after(self(), :poll, state.interval)
    {:noreply, %{state | generation: new_gen}}
  end

  @impl true
  def handle_info({:poll_result, gen, data, status}, %{generation: gen} = state) do
    merged = Map.merge(state.data, data)

    if merged != state.data or status != state.status do
      Charkeeper.broadcast(%{data: merged, status: status})
    end

    {:noreply, %{state | data: merged, status: status}}
  end

  @impl true
  def handle_info({:poll_result, _old_gen, _data, _status}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, %{data: state.data, status: state.status}, state}
  end

  defp fetch_all(ids, server) do
    ids
    |> Task.async_stream(
      fn {character_name, id} ->
        case Client.fetch(server, id) do
          {:ok, data} ->
            {character_name, data}

          {:error, reason} ->
            Logger.warning("Charkeeper fetch failed for #{character_name}: #{inspect(reason)}")
            nil
        end
      end,
      timeout: 8_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{}, fn
      {:ok, {name, data}}, acc -> Map.put(acc, name, data)
      _, acc -> acc
    end)
  end
end
