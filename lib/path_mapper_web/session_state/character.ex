defmodule PathMapperWeb.SessionState.Character do
  @moduledoc """
  Which character this browser session has claimed.

  A *player* is this and nothing more: a session holding a character's id. There
  is no player entity, nothing is stored, and closing the tab unclaims it.
  """

  alias PathMapper.Session.Resolve

  def key, do: :character

  def init do
    %{mine: nil, my_token_on_map: false}
  end

  def run_event(_, %{character: state}), do: state

  def set_character(state, mine, game_state) do
    %{state | mine: mine, my_token_on_map: on_map?(game_state, mine)}
  end

  def recompute(%{mine: nil} = state, _game_state), do: state

  def recompute(state, game_state) do
    mine = refresh(state.mine)
    %{state | mine: mine, my_token_on_map: on_map?(game_state, mine)}
  end

  # A claimed character that leaves the store is unclaimed, not remembered: the
  # claim names an id, and an id naming nothing resolves to nothing.
  defp refresh(%{id: id}), do: Resolve.character(id)
  defp refresh(_), do: nil

  defp on_map?(%{surface: %{tokens: tokens}}, %{id: id}) do
    Enum.any?(tokens, &(&1.owner == id))
  end

  defp on_map?(_, _), do: false
end
