defmodule PathMapper.Game.Actions.Scene do
  alias PathMapper.Game.Initialize
  alias PathMapper.Game.State

  def action(%State{active_scene: index} = state, [:scene, :select], index)
      when is_integer(index) do
    {:ok, state}
  end

  def action(%State{} = state, [:scene, :select], index) when is_integer(index) do
    if Map.has_key?(state.scenes, index) do
      {:ok, Map.put(state, :active_scene, index)}
    else
      {:error, "Scene #{index} not found in initialized scenes"}
    end
  end

  def action(%State{} = state, [:scene, :unset], _) do
    {:ok, Map.put(state, :active_scene, nil)}
  end

  def action(%State{active_scene: nil} = state, [:scene, :reset], _), do: {:ok, state}

  def action(%State{active_scene: index} = state, [:scene, :reset], _) do
    adventure_scene = State.scene(state).data
    new_scene = Initialize.build_scene(adventure_scene, index)
    {:ok, State.put_scene(state, new_scene)}
  end
end
