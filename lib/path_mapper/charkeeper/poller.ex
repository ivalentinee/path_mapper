defmodule PathMapper.Charkeeper.Poller do
  @moduledoc """
  Asks Charkeeper, on a timer, what the characters' numbers are now.

  It holds nothing about them. Each tick reads who to ask out of the session
  store and writes what came back into a table of its own, so there is no copy
  of the character list to keep in step and nothing to start or restart when
  one is declared. A session with no Charkeeper ids in it is a tick that
  selects nothing and makes no request.

  It used to be started with a list of ids, by `Game.reconcile/0`. That call
  was lost when characters replaced groups and nothing noticed: the poller
  simply never ran. A poller that derives its subjects cannot be left
  unstarted by a caller that forgot.
  """

  use GenServer

  require Logger

  alias PathMapper.Charkeeper
  alias PathMapper.Charkeeper.Client
  alias PathMapper.Session.Resolve

  @table __MODULE__
  @default_interval 10_000
  @status_key :status

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "What the last tick found, and how much of it it managed to fetch."
  def read do
    %{data: Map.new(characters()), status: status()}
  rescue
    ArgumentError -> %{data: %{}, status: nil}
  end

  @doc "Forgets everything, for a session that is being put away."
  def forget do
    :ets.delete_all_objects(@table)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    send(self(), :poll)
    {:ok, :ok}
  end

  # The fetches run here rather than in a task of their own. Nothing calls
  # this process - the readings are read straight from the table - so the
  # only thing a slow tick holds up is the next one, which is what we want
  # anyway: ticks cannot overlap, so there is no stale result to discard.
  @impl true
  def handle_info(:poll, state) do
    poll(server())
    Process.send_after(self(), :poll, interval())

    {:noreply, state}
  end

  defp poll(server) do
    subscriptions = Resolve.charkeeper_subscriptions()
    was = read()

    subscriptions
    |> fetch_all(server)
    |> record(subscriptions)

    now = read()
    if now != was, do: Charkeeper.broadcast(now)
  end

  # What came back is written over what was there, and a character the session
  # no longer holds is dropped. A character still held whose fetch failed this
  # tick keeps the numbers it had: the table is a last-known reading, and a
  # moment of network trouble should not blank the party.
  defp record(fetched, subscriptions) do
    held = Enum.map(subscriptions, fn {id, _charkeeper_id} -> id end)

    for {id, _data} <- characters(), id not in held, do: :ets.delete(@table, id)
    for {id, data} <- fetched, do: :ets.insert(@table, {id, data})

    :ets.insert(@table, {@status_key, status_of(fetched, subscriptions)})
  end

  defp status_of(_fetched, []), do: nil

  defp status_of(fetched, subscriptions) do
    cond do
      map_size(fetched) == length(subscriptions) -> :ok
      map_size(fetched) > 0 -> :partial
      true -> :error
    end
  end

  defp characters do
    for {id, data} <- :ets.tab2list(@table), id != @status_key, do: {id, data}
  end

  defp status do
    case :ets.lookup(@table, @status_key) do
      [{@status_key, status}] -> status
      [] -> nil
    end
  end

  defp fetch_all(subscriptions, server) do
    subscriptions
    |> Task.async_stream(
      fn {id, charkeeper_id} ->
        case Client.fetch(server, charkeeper_id) do
          {:ok, data} ->
            {id, data}

          {:error, reason} ->
            Logger.warning("Charkeeper fetch failed for #{id}: #{inspect(reason)}")
            nil
        end
      end,
      timeout: 8_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{}, fn
      {:ok, {id, data}}, acc -> Map.put(acc, id, data)
      _other, acc -> acc
    end)
  end

  defp interval,
    do: Application.get_env(:path_mapper, :charkeeper_poll_interval, @default_interval)

  defp server, do: Application.get_env(:path_mapper, :charkeeper_server, "charkeeper.ru")
end
