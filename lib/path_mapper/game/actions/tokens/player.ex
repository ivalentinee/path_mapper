defmodule PathMapper.Game.Actions.Tokens.Player do
  alias PathMapper.Game.Actions.Tokens
  alias PathMapper.Game.State
  alias PathMapper.Groups

  import PathMapper.Game.Actions.Tokens.Find

  # A player's own token takes the player's id as its suffix, so placing it again
  # mints the same game id and the collision rule dismisses it. There is no
  # "already placed" check here because there does not need to be one.
  def action(%State{} = state, [:tokens, :player, :add], id_or_index)
      when is_number(id_or_index) or is_binary(id_or_index) do
    case find_player_placement(id_or_index) do
      {token, game_id} -> Tokens.add_token(state, token, %{game_id: game_id})
      nil -> {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, :player, :add_all], _) do
    with {:ok, group} <- Groups.get_loaded(),
         player_ids <- Enum.map(group.players, & &1.id) do
      Enum.reduce(player_ids, {:ok, state}, fn
        player_id, {:ok, state} -> action(state, [:tokens, :player, :add], player_id)
        _player_id, error -> error
      end)
    else
      _ -> {:ok, state}
    end
  end

  # An extra token is a marking - a trap, an object - and a player may put down
  # as many as they like, so each placement mints its own id.
  def action(
        %State{} = state,
        [:tokens, :player, :add_extra],
        {player_id_or_index, extra_token_index}
      )
      when is_number(player_id_or_index) or is_binary(player_id_or_index) do
    case find_player_extra_token(player_id_or_index, extra_token_index) do
      nil -> {:ok, state}
      token -> Tokens.add_token(state, token)
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Player token action '#{inspect(action)}' not found"}
  end
end
