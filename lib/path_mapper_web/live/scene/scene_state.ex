defmodule PathMapperWeb.Scene.SceneState do
  defstruct snap_to_grid: true, active_tool: nil, grid_override: false, zoom: 1.0, pan: {0, 0}

  @zoom_min 0.5
  @zoom_max 3.0
  @zoom_step 0.25

  def run_event(%__MODULE__{} = scene_state, :snap_to_grid) do
    Map.put(scene_state, :snap_to_grid, !scene_state.snap_to_grid)
  end

  def run_event(%__MODULE__{} = scene_state, :zoom_in) do
    update_zoom(scene_state, @zoom_step)
  end

  def run_event(%__MODULE__{} = scene_state, :zoom_out) do
    update_zoom(scene_state, -@zoom_step)
  end

  def run_event(%__MODULE__{} = scene_state, :zoom_reset) do
    %{scene_state | zoom: 1.0, pan: {0, 0}}
  end

  def run_event(%__MODULE__{} = scene_state, {:map_zoom, delta}) when is_number(delta) do
    update_zoom(scene_state, delta * @zoom_step)
  end

  def run_event(%__MODULE__{} = scene_state, {:map_pan, {dx, dy}}) do
    {pan_x, pan_y} = scene_state.pan
    %{scene_state | pan: {pan_x + dx, pan_y + dy}}
  end

  def run_event(%__MODULE__{} = scene_state, _unknown_event) do
    scene_state
  end

  def reset_zoom(%__MODULE__{} = scene_state) do
    %{scene_state | zoom: 1.0, pan: {0, 0}}
  end

  defp update_zoom(%__MODULE__{} = scene_state, delta) do
    new_zoom = (scene_state.zoom + delta) |> max(@zoom_min) |> min(@zoom_max)
    %{scene_state | zoom: new_zoom}
  end
end
