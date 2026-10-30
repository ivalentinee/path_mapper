defmodule PathMapper.Game.Actions.Tokens.Character do
  @moduledoc """
  Putting a character's tokens on the active surface.

  A character addresses their own token and their markings by id, and the two
  differ in how often they may be placed: one character goes down once, a
  marking as often as asked.
  """

  alias PathMapper.Game.Actions.Tokens
  alias PathMapper.Game.State
  alias PathMapper.Session.Resolve

  import PathMapper.Game.Actions.Tokens.Find

  # A character's own token takes the character's id as its suffix, so placing it
  # again mints the same game id and the collision rule dismisses it. There is no
  # "already placed" check here because there does not need to be one.
  def action(%State{} = state, [:tokens, :character, :add], id) when is_binary(id) do
    case find_character_placement(id) do
      {token, game_id} -> Tokens.add_token(state, token, %{game_id: game_id})
      nil -> {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, :character, :add_all], _) do
    Resolve.characters()
    |> Enum.map(& &1.id)
    |> Enum.reduce({:ok, state}, fn
      id, {:ok, state} -> action(state, [:tokens, :character, :add], id)
      _id, error -> error
    end)
  end

  # A marking is a trap, an object, a note on the board, and a character may put
  # down as many as they like, so each placement mints its own id.
  def action(%State{} = state, [:tokens, :character, :add_extra], {id, extra_index})
      when is_binary(id) and is_number(extra_index) do
    case find_character_extra_token(id, extra_index) do
      nil -> {:ok, state}
      token -> Tokens.add_token(state, token)
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Character token action '#{inspect(action)}' not found"}
  end
end
