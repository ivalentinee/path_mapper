defmodule PathMapper.Session.Resolve do
  @moduledoc """
  What the store currently amounts to, asked one question at a time.

  The store is a flat table of pieces, so there is little left to denormalise: a
  map is a playable surface on its own, and a token, a wallpaper and a character
  each stand alone. What remains here is the asking — by kind, by id, in an
  order — and the one rule that cannot live in the store, which is that an id
  naming nothing answers nil rather than raising.

  Order is by id everywhere. Ids are fixed-width and zero-padded, so the string
  sort is the numeric one, and nothing carries a position of its own to disagree
  with it.
  """

  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store

  @doc "Every map the store holds, in id order. These are the playable surfaces."
  def surfaces do
    "map"
    |> of_kind()
    |> Enum.sort_by(& &1.id)
  end

  @doc "The map an id names, or nil."
  def surface(id) when is_binary(id) do
    case Store.fetch(id, "map") do
      {:ok, %Entity{data: data}} -> data
      {:error, _reason} -> nil
    end
  end

  def surface(_other), do: nil

  @doc """
  The wallpaper a viewer sees when no surface is active, or nil.

  Where the store holds more than one, the first by id. Nothing selects a
  wallpaper, because nothing can: the id is the only ordering available and it
  is the game master's to choose.
  """
  def wallpaper do
    "wallpaper"
    |> of_kind()
    |> Enum.min_by(& &1.id, fn -> nil end)
  end

  # Characters that name a Charkeeper character, read straight out of the
  # table. The poller asks this on a timer and it is the only question it has,
  # so the answer is selected rather than filtered out of every entity.
  #
  # The spec reaches into `Character`'s own fields, which is why it lives here
  # beside them rather than in the poller.
  @charkeeper_subscriptions [
    {{:_, %{kind: "character", data: %{id: :"$1", charkeeper_id: :"$2"}}}, [{:"/=", :"$2", nil}],
     [{{:"$1", :"$2"}}]}
  ]

  @doc "Every character that names a Charkeeper character, as `{id, charkeeper_id}`."
  def charkeeper_subscriptions, do: Store.select(@charkeeper_subscriptions)

  @doc "Every character the store holds, in id order."
  def characters do
    "character"
    |> of_kind()
    |> Enum.sort_by(& &1.id)
  end

  @doc "The character an id names, or nil."
  def character(id) when is_binary(id) do
    case Store.fetch(id, "character") do
      {:ok, %Entity{data: data}} -> data
      {:error, _reason} -> nil
    end
  end

  def character(_other), do: nil

  @doc """
  Every token the session holds, whatever declared it.

  Sorted by name where there is one and by id where there is not, so a nameless
  token sits among the rest rather than ahead of them or raising on the way
  past.
  """
  def tokens do
    "token"
    |> of_kind()
    |> Enum.sort_by(&sort_key/1)
  end

  @doc "The token an id names, or nil."
  def declared_token(id) when is_binary(id) do
    case Store.fetch(id, "token") do
      {:ok, %Entity{data: data}} -> data
      {:error, _reason} -> nil
    end
  end

  def declared_token(_id), do: nil

  defp of_kind(kind) do
    kind
    |> Store.of_kind()
    |> Enum.map(& &1.data)
  end

  defp sort_key(%{name: name}) when is_binary(name) and name != "", do: {0, name}
  defp sort_key(%{id: id}), do: {1, id}
end
