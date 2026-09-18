defmodule PathMapper.Session.Store do
  @moduledoc """
  What the session is made of, keyed by id.

  One flat table rather than a map per kind, because ids are unique everywhere:
  the same token can be a player's in one adventure and an NPC in another, and it
  is the same token. A composite `{kind, id}` key would be describing a boundary
  that does not exist.

  ETS rather than an Agent. Reads happen on every render and an Agent would put
  them all through one process; where a lookup wants to be fast that is data
  management's job rather than something to bend the data's shape around.
  """

  use GenServer

  alias PathMapper.Session.Entity

  @table __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, :ok}
  end

  @doc """
  Adds an entity, or replaces the one that id already holds.

  Replacing is ordinary: a shared token declared by a second adventure is the same
  token declared again. Changing an id's *kind* is not, and is refused - ids being
  unique everywhere is an author's discipline enforced nowhere else, and this turns
  a silent corruption into a message.
  """
  def put(%Entity{id: id, kind: kind} = entity) do
    case get(id) do
      %Entity{kind: ^kind} ->
        insert(entity)

      nil ->
        insert(entity)

      %Entity{kind: held} ->
        {:error, "#{id} is #{article(held)} #{held}, not #{article(kind)} #{kind}"}
    end
  end

  def get(id) when is_binary(id) do
    case :ets.lookup(@table, id) do
      [{^id, entity}] -> entity
      [] -> nil
    end
  end

  def get(_id), do: nil

  def fetch(id, kind) do
    case get(id) do
      %Entity{kind: ^kind} = entity ->
        {:ok, entity}

      %Entity{kind: held} ->
        {:error, "#{id} is #{article(held)} #{held}, not #{article(kind)} #{kind}"}

      nil ->
        {:error, "No #{kind} #{id}"}
    end
  end

  def delete(id) when is_binary(id) do
    :ets.delete(@table, id)
    :ok
  end

  def all, do: @table |> :ets.tab2list() |> Enum.map(fn {_id, entity} -> entity end)

  def of_kind(kind), do: Enum.filter(all(), &(&1.kind == kind))

  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  defp article(kind), do: if(String.starts_with?(kind, "a"), do: "an", else: "a")

  defp insert(%Entity{id: id} = entity) do
    :ets.insert(@table, {id, entity})
    {:ok, entity}
  end
end
