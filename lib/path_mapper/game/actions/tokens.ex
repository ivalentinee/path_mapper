defmodule PathMapper.Game.Actions.Tokens do
  alias PathMapper.Adventures.Adventure.Scene.Token
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Token, as: GameToken

  def action(%State{} = state, [:tokens, :add], index_or_name)
      when is_number(index_or_name) or is_binary(index_or_name) do
    token = find_adventure_token(state, index_or_name)

    if token do
      {x, y, size} = initial_token_geometry(state, token)
      color = Token.color(token)
      game_token = %GameToken{data: token, x: x, y: y, size: size, color: color, state: "alive"}
      updated_tokens = state.scene.tokens ++ [game_token]
      update_tokens(state, updated_tokens)
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, :delete], index) when is_number(index) do
    updated_tokens = List.delete_at(state.scene.tokens, index)
    update_tokens(state, updated_tokens)
  end

  def action(%State{} = state, [:tokens, index, :drag], {drag_x, drag_y})
      when is_number(index) and is_number(drag_x) and is_number(drag_y) do
    case Enum.at(state.scene.tokens, index) do
      %GameToken{} = game_token ->
        update_token(state, index, drag_token(game_token, drag_x, drag_y))

      _ ->
        {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, index, :move], {x, y})
      when is_number(index) and is_number(x) and is_number(y) do
    case Enum.at(state.scene.tokens, index) do
      %GameToken{} = game_token -> update_token(state, index, move_token(game_token, x, y))
      _ -> {:ok, state}
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Tokens action '#{inspect(action)}' not found"}
  end

  defp initial_token_geometry(%State{scene: %{map: %{grid_size: grid_size}}}, %Token{
         size: size
       }) do
    token_size = grid_size * size
    initial_coordinate = 0
    {initial_coordinate, initial_coordinate, token_size}
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

  defp drag_token(%GameToken{} = game_token, x, y) when is_number(x) and is_number(y) do
    game_token |> Map.put(:drag_x, x) |> Map.put(:drag_y, y)
  end

  defp move_token(%GameToken{} = game_token, x, y) when is_number(x) and is_number(y) do
    game_token
    |> Map.put(:drag_x, nil)
    |> Map.put(:drag_y, nil)
    |> Map.put(:x, x)
    |> Map.put(:y, y)
  end

  defp find_adventure_token(%State{} = state, index) when is_number(index) do
    Enum.at(state.scene.data.tokens, index)
  end

  defp find_adventure_token(%State{} = state, name) when is_binary(name) do
    Enum.find(state.scene.data.tokens, fn token -> token.name == name end)
  end
end
