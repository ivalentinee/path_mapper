defmodule PathMapper.Game.Actions do
  alias PathMapper.Adventures
  alias PathMapper.Game.State

  def action(%State{} = state, :select_scene, index) when is_number(index) do
    with {:ok, adventure} <- Adventures.get_loaded(),
         {:ok, adventure_scene} <- Adventures.Adventure.get_scene(adventure, index) do
      new_state = Map.put(state, :scene, State.Scene.initialize(adventure_scene, index))
      {:ok, new_state}
    else
      error -> error
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Action '#{action}' not found"}
  end
end
