defmodule PathMapper.Game.GameId do
  @moduledoc """
  The id a placement carries, as distinct from the token it was placed from.

  `tk0001-0000000042-left-guard`: a declaration's id, then anything. The prefix is
  what relates a placement to the thing placed, so it is the only part with a
  shape; the suffix is opaque here and is never read. An author writes one to
  name a placement in `place_tokens` - `-left-guard` beside `-right-guard` - and
  a placement made during play is given a random one.

  Nothing derives a placement's id from anything else, and nothing recomputes it.
  It is set when the placement is made and is the same id until the placement is
  gone.
  """

  alias PathMapper.Id

  @suffix_bytes 4

  @doc "A placement id for a declared token, with a generated suffix."
  def mint(token_id) when is_binary(token_id) do
    mint(token_id, random_suffix())
  end

  @doc """
  A placement id with the suffix given.

  A deterministic suffix makes placing the same thing twice produce the same id,
  which is how a player's own token is placed once without a rule of its own: the
  second attempt is a duplicate and is dismissed like any other.
  """
  def mint(token_id, suffix) when is_binary(token_id) and is_binary(suffix) do
    "#{token_id}-#{suffix}"
  end

  @doc "The declared token a placement id names, or nil if it names none."
  def token_id(game_id) when is_binary(game_id) do
    case Id.parse(game_id) do
      {:ok, id, _suffix} -> id
      :error -> nil
    end
  end

  def token_id(_game_id), do: nil

  defp random_suffix do
    @suffix_bytes |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
  end
end
