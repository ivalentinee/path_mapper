defmodule PathMapper.Game.Initialize do
  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene
  alias PathMapper.Adventures.Adventure.Scene.Token, as: AdventureToken
  alias PathMapper.Game.Actions.Tokens.FindFreeSpace
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Token, as: GameToken
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

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
    source_subpixel = params[:subpixel]

    build_params = %{
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
end
