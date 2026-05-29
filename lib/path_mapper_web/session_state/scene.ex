defmodule PathMapperWeb.SessionState.Scene do
  alias PathMapperWeb.Scene.SceneState

  def key, do: :scene

  def init, do: %SceneState{}

  def run_event(:snap_to_grid, %{scene: state}) do
    SceneState.run_event(state, :snap_to_grid)
  end

  def run_event(_, %{scene: state}), do: state
end
