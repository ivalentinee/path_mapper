defmodule PathMapper.Game.Actions.Tokens.FindFreeSpace do
  alias PathMapper.Game.State
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Geometry.OccupiedSpace
  alias PathMapper.Geometry.Point

  @doc """
  Compute initial position and size for a token being placed on a scene.

  Returns `{x, y, size}` in subpixel coordinates. `token_unit_size` is the
  token's size in grid cells (from the adventure definition).
  """
  def initial_token_geometry(%State.Scene{map: %{grid_size: grid_size}} = scene, token_unit_size)
      when is_number(token_unit_size) do
    token_size = GeometryMapper.to_subpixels(grid_size * token_unit_size)
    {x, y} = find_free_space(scene, token_size)
    {x, y, token_size}
  end

  @doc """
  Find a free position for a token of the given size (in subpixels).

  Scans grid-aligned positions row by row. Returns `{x, y}` in subpixels.
  Falls back to `{0, 0}` if no free space is found.
  """
  def find_free_space(%State.Scene{} = scene, token_size) when is_number(token_size) do
    occupied_spaces = get_occupied_spaces(scene)
    grid_size = GeometryMapper.to_subpixels(scene.map.grid_size)
    map_size = get_map_size(scene, token_size)
    iterate_through_possible_token_positions(grid_size, token_size, map_size, occupied_spaces)
  end

  def find_free_space(%State{} = state, token_size) when is_number(token_size) do
    find_free_space(State.scene(state), token_size)
  end

  defp get_occupied_spaces(%State.Scene{tokens: tokens}) do
    Enum.map(tokens, fn token ->
      %OccupiedSpace{
        from: %Point{x: token.x, y: token.y},
        to: %Point{x: token.x + token.size - 1, y: token.y + token.size - 1}
      }
    end)
  end

  defp iterate_through_possible_token_positions(
         grid_size,
         token_size,
         {map_width, map_height} = map_size,
         occupied_spaces,
         {x, y} = _position \\ {0, 0}
       ) do
    cond do
      y > map_height ->
        {0, 0}

      x > map_width ->
        iterate_through_possible_token_positions(
          grid_size,
          token_size,
          map_size,
          occupied_spaces,
          {0, y + grid_size}
        )

      overlaps_any?(occupied_spaces, x, y, token_size) ->
        iterate_through_possible_token_positions(
          grid_size,
          token_size,
          map_size,
          occupied_spaces,
          {x + grid_size, y}
        )

      true ->
        {x, y}
    end
  end

  defp get_map_size(%State.Scene{data: %{map: map}}, token_size) do
    {GeometryMapper.to_subpixels(map.width) - token_size,
     GeometryMapper.to_subpixels(map.height) - token_size}
  end

  defp overlaps_any?(occupied_spaces, x, y, token_size) do
    new_token = %OccupiedSpace{
      from: %Point{x: x, y: y},
      to: %Point{x: x + token_size - 1, y: y + token_size - 1}
    }

    Enum.any?(occupied_spaces, &rectangles_overlap?(&1, new_token))
  end

  defp rectangles_overlap?(%OccupiedSpace{from: a_from, to: a_to}, %OccupiedSpace{
         from: b_from,
         to: b_to
       }) do
    a_from.x <= b_to.x && a_to.x >= b_from.x && a_from.y <= b_to.y && a_to.y >= b_from.y
  end
end
