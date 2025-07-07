defmodule PathMapper.Game.Actions.Scene do
  alias PathMapper.Adventures
  alias PathMapper.Game.State

  def action(%State{} = state, [:scene, :select], index) when is_number(index) do
    with {:ok, adventure} <- Adventures.get_loaded(),
         {:ok, adventure_scene} <- Adventures.Adventure.get_scene(adventure, index) do
      new_state = Map.put(state, :scene, State.Scene.initialize(adventure_scene, index))
      {:ok, new_state}
    else
      error -> {:error, error}
    end
  end

  def action(%State{} = state, [:scene, :unset], _) do
    new_state = Map.put(state, :scene, nil)
    {:ok, new_state}
  end
end
