defmodule PathMapper.Game.Actions.Tokens.FindFreeSpace do
  alias PathMapper.Game.Actions.Tokens.OccupiedSpace
  alias PathMapper.Game.Actions.Tokens.Point
  alias PathMapper.Game.State

  def find_free_space(%State{} = state, token_size) when is_number(token_size) do
    occupied_spaces = get_occupied_spaces(state)
    grid_size = state.scene.map.grid_size
    map_size = get_map_size(state, token_size)
    iterate_through_possible_token_positions(grid_size, map_size, occupied_spaces)
  end

  defp get_occupied_spaces(%State{scene: %{tokens: tokens}}) do
    Enum.map(tokens, fn token ->
      %OccupiedSpace{
        from: %Point{x: token.x, y: token.y},
        to: %Point{x: token.x + token.size - 1, y: token.y + token.size - 1}
      }
    end)
  end

  defp iterate_through_possible_token_positions(
         grid_size,
         {map_width, _map_height} = map_size,
         occupied_spaces,
         {x, y} = position \\ {0, 0}
       ) do
    cond do
      x >= map_width ->
        {0, 0}

      Enum.find(occupied_spaces, &occupies(&1, position)) ->
        next_position = {x + grid_size, y}

        iterate_through_possible_token_positions(
          grid_size,
          map_size,
          occupied_spaces,
          next_position
        )

      true ->
        position
    end
  end

  defp get_map_size(%State{} = state, token_size),
    do: {state.scene.data.map.width - token_size, state.scene.data.map.height - token_size}

  defp occupies(%OccupiedSpace{from: from, to: to}, {x, y} = _position) do
    from.x <= x && from.y <= y && to.x >= x && to.y >= y
  end
end
