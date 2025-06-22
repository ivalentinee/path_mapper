defmodule PathMapper.Game.Actions.Tokens do
  alias PathMapper.Adventures.Adventure.Scene.Token
  alias PathMapper.Game.Actions.Tokens.FindFreeSpace
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Token, as: GameToken
  alias PathMapper.Groups

  require GameToken
  import PathMapper.Game.Actions.Tokens.Find
  import PathMapper.Game.Actions.Tokens.Move

  def action(%State{} = state, [:tokens, :add], index_or_name)
      when is_number(index_or_name) or is_binary(index_or_name) do
    token = find_adventure_token(state, index_or_name)

    if token do
      {x, y, size} = initial_token_geometry(state, token)

      game_token = %GameToken{
        data: token,
        x: x,
        y: y,
        size: size,
        color: token.color,
        state: "alive"
      }

      updated_tokens = state.scene.tokens ++ [game_token]
      update_tokens(state, updated_tokens)
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, :add_player], index_or_name)
      when is_number(index_or_name) or is_binary(index_or_name) do
    token = find_player_token(index_or_name)

    if token && !token_exists(state, token.name) do
      {x, y, size} = initial_token_geometry(state, token)

      game_token = %GameToken{
        data: token,
        x: x,
        y: y,
        size: size,
        color: token.color,
        state: "alive"
      }

      updated_tokens = state.scene.tokens ++ [game_token]
      update_tokens(state, updated_tokens)
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, :add_all_players], _) do
    with {:ok, group} <- Groups.get_loaded(),
         character_names <- Enum.map(group.players, & &1.character_name) do
      Enum.reduce(character_names, {:ok, state}, fn
        character_name, {:ok, state} -> action(state, [:tokens, :add_player], character_name)
        _character_name, error -> error
      end)
    else
      _ -> {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, :delete], index) when is_number(index) do
    updated_tokens = List.delete_at(state.scene.tokens, index)
    update_tokens(state, updated_tokens)
  end

  def action(%State{} = state, [:tokens, index, :set_state], token_state)
      when is_integer(index) and token_state in GameToken.states() do
    case Enum.at(state.scene.tokens, index) do
      %GameToken{} = game_token ->
        update_token(state, index, Map.put(game_token, :state, token_state))

      _ ->
        {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, index, :drag], {drag_x, drag_y, opts})
      when is_number(index) and is_number(drag_x) and is_number(drag_y) and is_map(opts) do
    case Enum.at(state.scene.tokens, index) do
      %GameToken{} = game_token ->
        update_token(state, index, drag_token(state, game_token, drag_x, drag_y, opts))

      _ ->
        {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, index, :move], {x, y, opts})
      when is_number(index) and is_number(x) and is_number(y) and is_map(opts) do
    case Enum.at(state.scene.tokens, index) do
      %GameToken{} = game_token ->
        update_token(state, index, move_token(state, game_token, x, y, opts))

      _ ->
        {:ok, state}
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Tokens action '#{inspect(action)}' not found"}
  end

  defp initial_token_geometry(%State{scene: %{map: %{grid_size: grid_size}}} = state, %Token{
         size: size
       }) do
    token_size = grid_size * size
    {x, y} = FindFreeSpace.find_free_space(state, token_size)
    {x, y, token_size}
  end

  defp update_token(%State{} = state, index, %GameToken{} = updated_token)
       when is_number(index) do
    updated_tokens = List.replace_at(state.scene.tokens, index, updated_token)
    update_tokens(state, updated_tokens)
  end

  defp update_tokens(%State{scene: scene} = state, updated_tokens) when is_list(updated_tokens) do
    updated_scene = Map.put(scene, :tokens, updated_tokens)
    {:ok, Map.put(state, :scene, updated_scene)}
  end
end
