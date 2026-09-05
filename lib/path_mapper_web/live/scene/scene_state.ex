defmodule PathMapperWeb.Scene.SceneState do
  defstruct snap_to_grid: true,
            active_tool: nil,
            grid_override: false,
            zoom: 1.0,
            pan: {0, 0},
            draw_color: "#8B4513",
            pending_prefix: nil,
            digit_buffer: "",
            draw_width: 4

  @zoom_min 0.5
  @zoom_max 3.0

  # Zoom is multiplicative in log2 space: new_zoom = zoom * 2 ** exponent.
  # An additive step cannot feel right across the range — +0.25 is a 50%
  # change at zoom 0.5 but a 9% change at 2.75 — because perceived zoom is
  # logarithmic. Formula and constants follow d3-zoom's `defaultWheelDelta`.
  @keyboard_zoom_exponent 0.25
  @wheel_pixel_factor 0.002
  @wheel_line_factor 0.05
  @wheel_page_factor 1.0
  @pinch_amplification 10

  def run_event(%__MODULE__{} = scene_state, :snap_to_grid) do
    Map.put(scene_state, :snap_to_grid, !scene_state.snap_to_grid)
  end

  def run_event(%__MODULE__{} = scene_state, :zoom_in) do
    zoom_by_exponent(scene_state, @keyboard_zoom_exponent)
  end

  def run_event(%__MODULE__{} = scene_state, :zoom_out) do
    zoom_by_exponent(scene_state, -@keyboard_zoom_exponent)
  end

  def run_event(%__MODULE__{} = scene_state, :zoom_reset) do
    %{scene_state | zoom: 1.0, pan: {0, 0}}
  end

  def run_event(%__MODULE__{} = scene_state, {:map_zoom, exponent, anchor})
      when is_number(exponent) do
    zoom_at(scene_state, exponent, anchor)
  end

  def run_event(%__MODULE__{} = scene_state, {:map_pan, {dx, dy}}) do
    {pan_x, pan_y} = scene_state.pan
    %{scene_state | pan: {pan_x + dx, pan_y + dy}}
  end

  def run_event(%__MODULE__{} = scene_state, {:set_draw_color, color}) when is_binary(color) do
    %{scene_state | draw_color: color}
  end

  def run_event(%__MODULE__{} = scene_state, {:set_draw_width, width})
      when is_integer(width) and width >= 1 and width <= 20 do
    %{scene_state | draw_width: width}
  end

  def run_event(%__MODULE__{} = scene_state, _unknown_event) do
    scene_state
  end

  def reset_zoom(%__MODULE__{} = scene_state) do
    %{scene_state | zoom: 1.0, pan: {0, 0}}
  end

  @doc """
  Zooms by `2 ** exponent`, keeping the map point under the cursor fixed.

  `anchor` is `{cursor_x, cursor_y, base_width, base_height, viewport_width,
  viewport_height}` in viewport pixels, where the base size is the
  fit-to-viewport map size *before* zoom is applied.

  Every value in `anchor` is independent of `zoom` and `pan`, which is what
  makes this safe under bursts: the current origin is derived here from this
  struct's own authoritative zoom/pan rather than from a rendered geometry
  snapshot. A snapshot taken in the caller lags by one round-trip, so wheel
  events queued behind an unprocessed zoom would all anchor against the same
  stale origin and the map would jump.

  Anchoring only binds on an axis where the map overflows the viewport. An
  axis that still fits after the step is centered by `rendered_origin/3`,
  which ignores pan by design.

  At a zoom limit the ratio is `1.0`, so zooming against the stop leaves the
  map where it is.
  """
  def zoom_at(
        %__MODULE__{} = scene_state,
        exponent,
        {cursor_x, cursor_y, base_width, base_height, viewport_width, viewport_height}
      ) do
    new_zoom = scaled_zoom(scene_state.zoom, exponent)
    {pan_x, pan_y} = scene_state.pan

    %{
      scene_state
      | zoom: new_zoom,
        pan: {
          anchor_axis(cursor_x, pan_x, base_width, scene_state.zoom, new_zoom, viewport_width),
          anchor_axis(cursor_y, pan_y, base_height, scene_state.zoom, new_zoom, viewport_height)
        }
    }
  end

  @doc """
  The on-screen origin of one map axis.

  Centers the map when it fits the viewport (pan is ignored in that case),
  otherwise clamps pan so the map cannot be dragged past its own edges.
  Shared with `SceneComponent.apply_axis/5` so the rendered position and the
  zoom anchoring agree on exactly one definition.
  """
  def rendered_origin(pan, map_size, viewport_size) do
    if map_size <= viewport_size do
      floor((viewport_size - map_size) / 2)
    else
      pan |> max(viewport_size - map_size) |> min(0)
    end
  end

  defp anchor_axis(cursor, pan, base_size, old_zoom, new_zoom, viewport_size) do
    old_origin = rendered_origin(pan, base_size * old_zoom, viewport_size)
    cursor - (cursor - old_origin) * (new_zoom / old_zoom)
  end

  @doc """
  Converts one wheel event into a log2 zoom exponent.

  Mirrors d3-zoom's `defaultWheelDelta`: normalises `deltaMode` (pixel,
  line, page) so hi-res wheels and notched wheels behave alike, and
  amplifies `ctrl_key` events, which is how browsers deliver a trackpad
  pinch gesture rather than as touch events.
  """
  def wheel_exponent(delta_y, delta_mode, ctrl_key) when is_number(delta_y) do
    -delta_y * mode_factor(delta_mode) * if(ctrl_key, do: @pinch_amplification, else: 1)
  end

  @doc """
  Multiplies zoom by `2 ** exponent`, clamped. Leaves pan untouched.
  """
  def zoom_by_exponent(%__MODULE__{} = scene_state, exponent) do
    %{scene_state | zoom: scaled_zoom(scene_state.zoom, exponent)}
  end

  defp mode_factor(1), do: @wheel_line_factor
  defp mode_factor(2), do: @wheel_page_factor
  defp mode_factor(_pixel), do: @wheel_pixel_factor

  defp scaled_zoom(zoom, exponent), do: clamp_zoom(zoom * :math.pow(2, exponent))

  defp clamp_zoom(zoom), do: zoom |> max(@zoom_min) |> min(@zoom_max)
end
