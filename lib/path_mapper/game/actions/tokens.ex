defmodule PathMapper.Game.Actions.Tokens do
  alias Ecto.Changeset
  alias PathMapper.Adventures.Adventure.Scene.Token
  alias PathMapper.Game.Actions.Tokens.FindFreeSpace
  alias PathMapper.Game.GameId
  alias PathMapper.Game.Palette
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Token, as: GameToken
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  require PathMapper.TokenStates
  import PathMapper.Errors
  import PathMapper.Game.Actions.Tokens.Find
  import PathMapper.Game.Actions.Tokens.Move
  import PathMapper.TokenStates, only: [states: 0]

  def action(%State{} = state, [:tokens, :player | _rest] = action, data),
    do: __MODULE__.Player.action(state, action, data)

  def action(%State{} = state, [:tokens, :add], index_or_name)
      when is_number(index_or_name) or is_binary(index_or_name) do
    params = %{}
    action(state, [:tokens, :add], {index_or_name, params})
  end

  def action(%State{} = state, [:tokens, :add], {index_or_name, params})
      when (is_number(index_or_name) or is_binary(index_or_name)) and is_map(params) do
    token = find_adventure_token(state, index_or_name)

    if token do
      add_token(state, token, params)
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, :delete], game_id) when is_binary(game_id) do
    case position_of(state, game_id) do
      nil -> {:ok, state}
      index -> update_tokens(state, List.delete_at(State.scene(state).tokens, index))
    end
  end

  def action(%State{} = state, [:tokens, game_id, :set_state], token_state)
      when is_binary(game_id) and token_state in states() do
    with_placement(state, game_id, fn index, game_token ->
      update_token(state, index, Map.put(game_token, :state, token_state))
    end)
  end

  def action(%State{} = state, [:tokens, game_id, :drag], {drag_x, drag_y, opts})
      when is_binary(game_id) and is_number(drag_x) and is_number(drag_y) and is_map(opts) do
    with_placement(state, game_id, fn index, game_token ->
      update_token(state, index, drag_token(state, game_token, drag_x, drag_y, opts))
    end)
  end

  def action(%State{} = state, [:tokens, game_id, :move], {x, y, opts})
      when is_binary(game_id) and is_number(x) and is_number(y) and is_map(opts) do
    with_placement(state, game_id, fn index, game_token ->
      update_token(state, index, move_token(state, game_token, x, y, opts))
    end)
  end

  # Clearing is setting it to nil rather than a second action: a placement with no
  # name of its own shows the declaration's, which is what resolution already does.
  def action(%State{} = state, [:tokens, game_id, :set_name], name)
      when is_binary(game_id) and (is_binary(name) or is_nil(name)) do
    with_placement(state, game_id, fn index, game_token ->
      update_token(state, index, Map.put(game_token, :name, blank_to_nil(name)))
    end)
  end

  def action(%State{} = state, [:tokens, game_id, :set_owner], new_owner)
      when is_binary(game_id) and is_binary(new_owner) do
    if Map.has_key?(Palette.get(), new_owner) do
      with_placement(state, game_id, fn index, game_token ->
        update_token(state, index, Map.put(game_token, :owner, new_owner))
      end)
    else
      {:ok, state}
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Tokens action '#{inspect(action)}' not found"}
  end

  # A command acts on exactly the placement its id matches, so an id the scene
  # does not hold leaves the scene as it was rather than failing. A stale id is
  # what a second browser sends after someone else removed the token.
  defp with_placement(%State{} = state, game_id, change) do
    case position_of(state, game_id) do
      nil -> {:ok, state}
      index -> change.(index, Enum.at(State.scene(state).tokens, index))
    end
  end

  defp blank_to_nil(name) when is_binary(name) do
    case String.trim(name) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(nil), do: nil

  defp position_of(%State{} = state, game_id) do
    Enum.find_index(State.scene(state).tokens, &(&1.game_id == game_id))
  end

  @doc """
  Places a declared token on the active scene.

  The placement takes the game id it was given, or one minted for it. An id the
  scene already holds means this placement has been made before, so it is
  dismissed and reported rather than added twice - which is also what places a
  player's own token once, since its id is derived from the player.
  """
  def add_token(%State{} = state, token, params \\ %{}) when is_map(params) do
    {x, y, size} = initial_token_geometry(state, token)
    source_subpixel = params[:subpixel]
    game_id = params[:game_id] || GameId.mint(token.id)

    build_params = %{
      game_id: game_id,
      x: placed_coordinate(params[:x], x, source_subpixel),
      y: placed_coordinate(params[:y], y, source_subpixel),
      size: size,
      owner: token.owner,
      state: params[:state] || "alive"
    }

    if placement_exists(state, game_id) do
      {:ok, state, [game_id]}
    else
      insert_placement(state, build_params, token)
    end
  end

  defp placed_coordinate(nil, fallback, _source_subpixel), do: fallback

  defp placed_coordinate(given, _fallback, source_subpixel),
    do: GeometryMapper.coordinate_to_subpixels(given, source_subpixel)

  defp insert_placement(%State{} = state, params, token) do
    case GameToken.build(params, token) do
      {:ok, game_token} ->
        update_tokens(state, State.scene(state).tokens ++ [game_token])

      {:error, %Changeset{} = changeset} ->
        {:error, display_errors(changeset)}

      {:error, error} ->
        {:error, error}
    end
  end

  def initial_token_geometry(%State{} = state, %Token{size: size}) do
    FindFreeSpace.initial_token_geometry(State.scene(state), size)
  end

  def update_tokens(%State{} = state, updated_tokens) when is_list(updated_tokens) do
    updated_scene = Map.put(State.scene(state), :tokens, updated_tokens)
    {:ok, State.put_scene(state, updated_scene)}
  end

  defp update_token(%State{} = state, index, %GameToken{} = updated_token)
       when is_number(index) do
    updated_tokens = List.replace_at(State.scene(state).tokens, index, updated_token)
    update_tokens(state, updated_tokens)
  end
end
