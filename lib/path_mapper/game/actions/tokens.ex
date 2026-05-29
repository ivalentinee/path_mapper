defmodule PathMapper.Game.Actions.Tokens do
  alias Ecto.Changeset
  alias PathMapper.Adventures.Adventure.Scene.Token
  alias PathMapper.Game.Actions.Tokens.FindFreeSpace
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

  def action(%State{} = state, [:tokens, :delete], index) when is_number(index) do
    updated_tokens = List.delete_at(State.scene(state).tokens, index)
    update_tokens(state, updated_tokens)
  end

  def action(%State{} = state, [:tokens, index, :set_state], token_state)
      when is_integer(index) and token_state in states() do
    case Enum.at(State.scene(state).tokens, index) do
      %GameToken{} = game_token ->
        update_token(state, index, Map.put(game_token, :state, token_state))

      _ ->
        {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, index, :drag], {drag_x, drag_y, opts})
      when is_number(index) and is_number(drag_x) and is_number(drag_y) and is_map(opts) do
    case Enum.at(State.scene(state).tokens, index) do
      %GameToken{} = game_token ->
        update_token(state, index, drag_token(state, game_token, drag_x, drag_y, opts))

      _ ->
        {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, index, :move], {x, y, opts})
      when is_number(index) and is_number(x) and is_number(y) and is_map(opts) do
    case Enum.at(State.scene(state).tokens, index) do
      %GameToken{} = game_token ->
        update_token(state, index, move_token(state, game_token, x, y, opts))

      _ ->
        {:ok, state}
    end
  end

  def action(%State{} = state, [:tokens, index, :set_owner], new_owner)
      when is_integer(index) and is_binary(new_owner) do
    if Map.has_key?(Palette.get(), new_owner) do
      case Enum.at(State.scene(state).tokens, index) do
        %GameToken{} = game_token ->
          update_token(state, index, Map.put(game_token, :owner, new_owner))

        _ ->
          {:ok, state}
      end
    else
      {:ok, state}
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Tokens action '#{inspect(action)}' not found"}
  end

  def add_token(%State{} = state, token, params \\ %{}) when is_map(params) do
    {x, y, size} = initial_token_geometry(state, token)
    source_subpixel = params[:subpixel]

    params = %{
      x:
        if(params[:x],
          do: GeometryMapper.coordinate_to_subpixels(params[:x], source_subpixel),
          else: x
        ),
      y:
        if(params[:y],
          do: GeometryMapper.coordinate_to_subpixels(params[:y], source_subpixel),
          else: y
        ),
      size: size,
      owner: token.owner,
      state: params[:state] || "alive"
    }

    case GameToken.build(params, token) do
      {:ok, game_token} ->
        updated_tokens = State.scene(state).tokens ++ [game_token]
        update_tokens(state, updated_tokens)

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
