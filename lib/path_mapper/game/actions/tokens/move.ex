defmodule PathMapper.Game.Actions.Tokens.Move do
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Token, as: GameToken

  def drag_token(%State{} = state, %GameToken{} = game_token, x, y, %{snap: true})
      when is_number(x) and is_number(y) do
    {snapped_x, snapped_y} = snap_position(state, x, y)
    drag_token(state, game_token, snapped_x, snapped_y, %{})
  end

  def drag_token(%State{}, %GameToken{} = game_token, x, y, opts)
      when is_number(x) and is_number(y)
      when is_map(opts) do
    game_token |> Map.put(:drag_x, x) |> Map.put(:drag_y, y)
  end

  def move_token(%State{} = state, %GameToken{} = game_token, x, y, %{snap: true})
      when is_number(x) and is_number(y) do
    {snapped_x, snapped_y} = snap_position(state, x, y)
    move_token(state, game_token, snapped_x, snapped_y, %{})
  end

  def move_token(%State{}, %GameToken{} = game_token, x, y, opts)
      when is_number(x) and is_number(y) and is_map(opts) do
    game_token
    |> Map.put(:drag_x, nil)
    |> Map.put(:drag_y, nil)
    |> Map.put(:x, x)
    |> Map.put(:y, y)
  end

  defp snap_position(%State{} = state, x, y) do
    grid_size = state.scene.map.grid_size

    {
      round(x / grid_size) * grid_size,
      round(y / grid_size) * grid_size
    }
  end
end
