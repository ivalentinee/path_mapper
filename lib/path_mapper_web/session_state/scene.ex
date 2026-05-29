defmodule PathMapperWeb.SessionState.Scene do
  alias PathMapperWeb.Scene.SceneState

  @tools [:ruler, :pointer, :burst, :emanation, :cone, :line]

  def key, do: :scene

  def init, do: %SceneState{}

  def run_event(:snap_to_grid, %{scene: state}) do
    SceneState.run_event(state, :snap_to_grid)
  end

  def run_event({:select_tool, tool}, %{scene: state}) when tool in @tools do
    if state.active_tool == tool do
      %{state | active_tool: nil}
    else
      %{state | active_tool: tool}
    end
  end

  def run_event(:deselect_tool, %{scene: state}) do
    %{state | active_tool: nil}
  end

  def run_event(:toggle_grid_override, %{scene: state}) do
    %{state | grid_override: !state.grid_override}
  end

  def run_event(_, %{scene: state}), do: state
end
