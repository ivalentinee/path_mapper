defmodule PathMapper.Game.Actions.Scene do
  alias PathMapper.Adventures
  alias PathMapper.Adventures.Adventure.Scene
  alias PathMapper.Game.Actions
  alias PathMapper.Game.State

  def action(%State{} = state, [:scene, :select], index) when is_number(index) do
    with {:ok, adventure} <- Adventures.get_loaded(),
         {:ok, adventure_scene} <- Adventures.Adventure.get_scene(adventure, index) do
      new_state = Map.put(state, :scene, State.Scene.initialize(adventure_scene, index))
      place_tokens(new_state, adventure_scene)
    else
      error -> {:error, error}
    end
  end

  def action(%State{} = state, [:scene, :unset], _) do
    new_state = Map.put(state, :scene, nil)
    {:ok, new_state}
  end

  defp place_tokens(%State{} = state, %Scene{place_tokens: place_tokens})
       when is_list(place_tokens) do
    Enum.reduce(place_tokens, {:ok, state}, &place_token/2)
  end

  defp place_tokens(state, _scene), do: {:ok, state}

  defp place_token(place_token, {:ok, state}),
    do: Actions.action(state, [:tokens, :add], {place_token.name, Map.from_struct(place_token)})

  defp place_token(_place_token, {:error, error}), do: {:error, error}
end
