defmodule PathMapper.Game.Initialize do
  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene
  alias PathMapper.Adventures.Adventure.Scene.Token, as: AdventureToken
  alias PathMapper.Game.Actions.Tokens.FindFreeSpace
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Token, as: GameToken

  def build_all(%Adventure{scenes: adventure_scenes}) do
    adventure_scenes
    |> Enum.with_index()
    |> Map.new(fn {adventure_scene, index} ->
      {index, build_scene(adventure_scene, index)}
    end)
  end

  def build_scene(%AdventureScene{} = adventure_scene, index) do
    adventure_scene
    |> State.Scene.initialize(index)
    |> place_initial_tokens(adventure_scene)
  end

  defp place_initial_tokens(scene, %AdventureScene{place_tokens: place_tokens})
       when is_list(place_tokens) do
    Enum.reduce(place_tokens, scene, &place_token(&1, &2))
  end

  defp place_initial_tokens(scene, _adventure_scene), do: scene

  defp place_token(place_token, %State.Scene{} = scene) do
    token = find_token(scene, place_token.name)

    if token do
      build_and_add_token(scene, token, Map.from_struct(place_token))
    else
      scene
    end
  end

  defp find_token(%State.Scene{data: %{tokens: tokens}}, name) do
    Enum.find(tokens, &(&1.name == name))
  end

  defp build_and_add_token(%State.Scene{} = scene, %AdventureToken{} = token, params) do
    {x, y, size} = token_geometry(scene, token)

    build_params = %{
      x: params[:x] || x,
      y: params[:y] || y,
      size: size,
      color: token.color,
      state: params[:state] || "alive"
    }

    case GameToken.build(build_params, token) do
      {:ok, game_token} ->
        Map.update!(scene, :tokens, &(&1 ++ [game_token]))

      _ ->
        scene
    end
  end

  defp token_geometry(%State.Scene{map: %{grid_size: grid_size}} = scene, %AdventureToken{
         size: size
       }) do
    token_size = grid_size * size
    {x, y} = FindFreeSpace.find_free_space(scene, token_size)
    {x, y, token_size}
  end
end
