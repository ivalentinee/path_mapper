defmodule PathMapper.Game.Actions.Tokens.Player do
  alias PathMapper.Game.Actions.Tokens
  alias PathMapper.Game.State
  alias PathMapper.Groups

  import PathMapper.Game.Actions.Tokens.Find

  def action(%State{} = state, [:tokens, :player, :add], index_or_name)
      when is_number(index_or_name) or is_binary(index_or_name) do
    token = find_player_token(index_or_name)

    if token && !token_exists(state, token.id) do
      Tokens.add_token(state, token)
    else
      {:ok, state}
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

  def action(
        %State{} = state,
        [:tokens, :player, :add_extra],
        {player_index_or_name, extra_token_index}
      )
      when is_number(player_index_or_name) or is_binary(player_index_or_name) do
    token = find_player_extra_token(player_index_or_name, extra_token_index)

    if token do
      Tokens.add_token(state, token)
    else
      {:ok, state}
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Player token action '#{inspect(action)}' not found"}
  end
end
