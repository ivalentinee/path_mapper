defmodule PathMapperWeb.SessionState.Scene do
  alias PathMapperWeb.Scene.SceneState

  @tools [
    :ruler,
    :pointer,
    :burst,
    :emanation,
    :cone,
    :line,
    :map,
    :fill,
    :rect,
    :draw_line,
    :draw_circle,
    :text,
    :eraser
  ]

  def key, do: :scene

  def init, do: %SceneState{}

  def run_event(:snap_to_grid, %{scene: state}) do
    SceneState.run_event(state, :snap_to_grid)
  end

  def run_event({:select_tool, tool}, %{scene: state}) when tool in @tools do
    if state.active_tool == tool do
      %{state | active_tool: nil, pending_prefix: nil}
    else
      %{state | active_tool: tool, pending_prefix: nil}
    end
  end

  def run_event(:deselect_tool, %{scene: state}) do
    %{state | active_tool: nil, pending_prefix: nil}
  end

  def run_event(:toggle_grid_override, %{scene: state}) do
    %{state | grid_override: !state.grid_override}
  end

  def run_event({:set_draw_color, color}, %{scene: state}),
    do: SceneState.run_event(state, {:set_draw_color, color})

  def run_event(:zoom_in, %{scene: state}), do: SceneState.run_event(state, :zoom_in)
  def run_event(:zoom_out, %{scene: state}), do: SceneState.run_event(state, :zoom_out)
  def run_event(:zoom_reset, %{scene: state}), do: SceneState.run_event(state, :zoom_reset)

  def run_event({:map_zoom, delta}, %{scene: state}),
    do: SceneState.run_event(state, {:map_zoom, delta})

  def run_event({:map_pan, delta}, %{scene: state}),
    do: SceneState.run_event(state, {:map_pan, delta})

  def run_event(_, %{scene: state}), do: state
end
