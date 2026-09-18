defmodule PathMapper.Session.Entity do
  @moduledoc """
  A thing the session is made of: an id, what kind of thing it is, and its payload.

  The kinds are deliberately few. An adventure and a group are little more than a
  name; a scene, a map and a token are what a session is actually built from.
  """

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene.Map, as: SceneMap
  alias PathMapper.Adventures.Adventure.Scene.Token
  alias PathMapper.Groups.Group
  alias PathMapper.Session.Scene

  @enforce_keys [:id, :kind, :data]
  defstruct [:id, :kind, :data]

  @kinds %{
    "adventure" => Adventure,
    "group" => Group,
    "scene" => Scene,
    "map" => SceneMap,
    "token" => Token
  }

  def kinds, do: Elixir.Map.keys(@kinds)

  def schema(kind), do: Elixir.Map.fetch(@kinds, kind)

  @doc "Builds an entity from a command's payload, or says why it cannot."
  def build(kind, %{"id" => id} = params) when is_binary(id) do
    with {:ok, schema} <- fetch_schema(kind),
         {:ok, data} <- cast(schema, params) do
      {:ok, %__MODULE__{id: id, kind: kind, data: data}}
    end
  end

  def build(_kind, _params), do: {:error, "An entity needs an id"}

  defp fetch_schema(kind) do
    case schema(kind) do
      {:ok, schema} -> {:ok, schema}
      :error -> {:error, "No such kind: #{kind} (expected one of #{Enum.join(kinds(), ", ")})"}
    end
  end

  defp cast(schema, params) do
    schema
    |> struct()
    |> schema.changeset(params)
    |> Ecto.Changeset.apply_action(:insert)
  end
end
