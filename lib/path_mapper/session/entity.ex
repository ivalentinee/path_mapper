defmodule PathMapper.Session.Entity do
  @moduledoc """
  A thing the session is made of: an id, what kind of thing it is, and its payload.

  Four kinds, and none of them holds another. A map is a playable surface, a token
  stands on one, a wallpaper is what a viewer sees when none is active, and a
  character is someone in the game. Anything that gathers these — an adventure, a
  group — is a package, and a package is the client's.

  These modules are never aliased bare: `alias PathMapper.Session` and then
  `Session.Map`, because `Map` is Elixir's and rebinding it is a runtime error the
  compiler only warns about.
  """

  alias PathMapper.Session

  @enforce_keys [:id, :kind, :data]
  defstruct [:id, :kind, :data]

  @kinds %{
    "map" => Session.Map,
    "token" => Session.Token,
    "wallpaper" => Session.Wallpaper,
    "character" => Session.Character
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
