defmodule PathMapperWeb.SessionState.Character do
  def key, do: :character

  def init do
    %{my_player: nil, my_token_on_map: false}
  end

  # claim_character is handled by PlayerLive directly (needs domain data).
  # The plugin stores the result via set_player/recompute.

  def run_event(_, %{character: state}), do: state

  def set_player(state, my_player, game_state) do
    %{state | my_player: my_player, my_token_on_map: compute_on_map(game_state, my_player)}
  end

  def recompute(%{my_player: nil} = state, _game_state, _group), do: state

  def recompute(state, game_state, group) do
    my_player = refresh_player(state.my_player, group)
    %{state | my_player: my_player, my_token_on_map: compute_on_map(game_state, my_player)}
  end

  defp refresh_player(%{character_name: name}, group) when not is_nil(group) do
    Enum.find(group.players, &(&1.character_name == name))
  end

  defp refresh_player(_, _), do: nil

  defp compute_on_map(%{scene: %{tokens: tokens}}, %{character_name: name}) do
    Enum.any?(tokens, &(&1.data.name == name))
  end

  defp compute_on_map(_, _), do: false
end
