defmodule PathMapperWeb.Scene.SceneState do
  defstruct snap_to_grid: true

  def run_event(%__MODULE__{} = scene_state, :snap_to_grid) do
    Map.put(scene_state, :snap_to_grid, !scene_state.snap_to_grid)
  end

  def run_event(%__MODULE__{} = scene_state, _unknown_event) do
    scene_state
  end
end
