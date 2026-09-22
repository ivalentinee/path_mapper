defmodule PathMapper.Game.Initialize do
  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene
  alias PathMapper.Adventures.Adventure.Scene.Token, as: AdventureToken
  alias PathMapper.Game.Actions.Tokens.FindFreeSpace
  alias PathMapper.Game.GameId
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Token, as: GameToken
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Session.Resolve

  def build_all(%Adventure{scenes: adventure_scenes}) do
    adventure_scenes
    |> Enum.with_index()
    |> Map.new(fn {adventure_scene, order} ->
      {scene, _dismissed} = build_scene(adventure_scene, order)
      {adventure_scene.id, scene}
    end)
  end

  @doc """
  Builds a scene and places the tokens its entries name.

  Answers the scene and the game ids it declined: an entry naming an id the scene
  already holds is dismissed, and the placement holding that id stands. Two
  entries for one token used to be ordinary, so this is the mistake an adventure
  written against the old form makes, and it is reported rather than swallowed.
  """
  def build_scene(%AdventureScene{} = adventure_scene, order) do
    adventure_scene
    |> State.Scene.initialize(order)
    |> place_initial_tokens(adventure_scene)
  end

  defp place_initial_tokens(scene, %AdventureScene{place_tokens: place_tokens})
       when is_list(place_tokens) do
    Enum.reduce(place_tokens, {scene, []}, fn entry, {scene, dismissed} ->
      place_token(entry, scene, dismissed)
    end)
  end

  defp place_initial_tokens(scene, _adventure_scene), do: {scene, []}

  # An entry names the token it places through its game id's prefix, so a scene
  # that no longer declares that token skips the entry rather than failing: the
  # author changed the adventure, and that is a decision rather than a mistake.
  defp place_token(place_token, %State.Scene{} = scene, dismissed) do
    token = find_token(scene, GameId.token_id(place_token.game_id))

    cond do
      is_nil(token) -> {scene, dismissed}
      taken?(scene, place_token.game_id) -> {scene, dismissed ++ [place_token.game_id]}
      true -> {build_and_add_token(scene, token, Map.from_struct(place_token)), dismissed}
    end
  end

  # The scene's own roster first, since a scene may override a token's name, size
  # or owner for itself; then the store, so an entry may place any token the
  # session holds. An id naming nothing still places nothing.
  defp find_token(%State.Scene{data: %{tokens: tokens}}, id) when is_binary(id) do
    Enum.find(tokens, &(&1.id == id)) || Resolve.declared_token(id)
  end

  defp find_token(_scene, id) when is_binary(id), do: Resolve.declared_token(id)

  defp find_token(_scene, _id), do: nil

  defp taken?(%State.Scene{tokens: tokens}, game_id) do
    Enum.any?(tokens, &(&1.game_id == game_id))
  end

  # Every fact the copy states is read here, and a fact it omits is taken from the
  # declaration. The two sides are one contract: an entry written by
  # `to_place_records/2` places the placement it was written from.
  defp build_and_add_token(%State.Scene{} = scene, %AdventureToken{} = token, params) do
    {x, y, size} = token_geometry(scene, token)
    grid = State.Scene.grid_size(scene)

    build_params = %{
      x: placed_at(params[:x], x, grid),
      y: placed_at(params[:y], y, grid),
      size: size,
      owner: params[:owner] || token.owner,
      state: params[:state] || "alive",
      game_id: params[:game_id],
      name: params[:name]
    }

    case GameToken.build(build_params, token) do
      {:ok, game_token} ->
        Map.update!(scene, :tokens, &(&1 ++ [game_token]))

      _ ->
        scene
    end
  end

  defp token_geometry(%State.Scene{} = scene, %AdventureToken{size: size}) do
    FindFreeSpace.initial_token_geometry(scene, size)
  end

  # A stated position is a count of grid cells; an omitted one is wherever the
  # scene has room.
  defp placed_at(nil, fallback, _grid), do: fallback
  defp placed_at(cells, _fallback, grid), do: GeometryMapper.from_cells(cells, grid)
end
