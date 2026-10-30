defmodule PathMapper.Game.Actions.Tokens.Find do
  @moduledoc """
  Finding the token a command means.

  A character names its tokens by id and the tokens are pieces in the store, so
  there is nothing to synthesise here any more. What used to build a token out
  of a player's fields — its name from the character's, its owner from the
  player's id, its image from an asset path — now reads a token the client
  uploaded, which carries all three itself.
  """

  alias PathMapper.Game.GameId
  alias PathMapper.Game.State
  alias PathMapper.Session.Resolve

  @doc "The placement holding this game id on the active surface, if any."
  def placement_exists(%State{} = state, game_id) when is_binary(game_id) do
    Enum.find(State.surface(state).tokens, &(&1.game_id == game_id))
  end

  @doc """
  The token an id names.

  One answer for every caller. A surface no longer carries a roster of its own,
  so there is no per-surface override to consult first and no second place a
  token could hide.
  """
  def find_token(id) when is_binary(id), do: Resolve.declared_token(id)
  def find_token(_id), do: nil

  @doc "A character's own token, or nil."
  def find_character_token(character_id) when is_binary(character_id) do
    with %{token_id: token_id} <- Resolve.character(character_id) do
      find_token(token_id)
    end
  end

  def find_character_token(_id), do: nil

  @doc """
  A character's own token and the game id its placement always takes.

  The id is derived from the character rather than minted, so a character holds
  one placement of their own token on a surface without any rule saying so:
  asking twice produces the same id, and the second is a duplicate.
  """
  def find_character_placement(character_id) when is_binary(character_id) do
    with %{token_id: token_id} = character when is_binary(token_id) <-
           Resolve.character(character_id),
         token when not is_nil(token) <- find_token(token_id) do
      {token, GameId.mint(token_id, character.id)}
    else
      _ -> nil
    end
  end

  def find_character_placement(_id), do: nil

  @doc "One of a character's extra tokens, by its position in their list."
  def find_character_extra_token(character_id, index)
      when is_binary(character_id) and is_number(index) do
    with %{extra_token_ids: ids} <- Resolve.character(character_id),
         id when is_binary(id) <- Enum.at(List.wrap(ids), index) do
      find_token(id)
    else
      _ -> nil
    end
  end

  def find_character_extra_token(_id, _index), do: nil

  @doc "Every token id the characters carry, their own and their markings."
  def character_token_ids do
    Resolve.characters()
    |> Enum.flat_map(&[&1.token_id | List.wrap(&1.extra_token_ids)])
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end
end
