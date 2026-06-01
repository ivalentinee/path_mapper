defmodule PathMapper.MapTools.Shapes do
  @moduledoc false

  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  @type shape :: %{type: atom()}

  @doc """
  Computes shape geometry for a tool draw. All coordinates and grid_size
  are in subpixel units (integers). Returns subpixel-space values.
  The caller uses GeometryMapper.scale_to/2 for screen-pixel conversion.

  Non-coordinate values (angle, distance) are in their natural units.
  """
  @spec compute(map(), number()) :: shape()
  def compute(%{"mode" => "grid"} = tool_data, grid_size) do
    grid_cells(tool_data, grid_size)
  end

  def compute(%{"tool" => "ruler", "mode" => "path"} = tool_data, grid_size) do
    ruler_path(tool_data, grid_size)
  end

  def compute(%{"tool" => "ruler"} = tool_data, _grid_size) do
    ruler(tool_data)
  end

  def compute(%{"tool" => "pointer"} = tool_data, _grid_size) do
    pointer(tool_data)
  end

  def compute(%{"tool" => tool} = tool_data, _grid_size) when tool in ~w(burst emanation) do
    circle(tool_data)
  end

  def compute(%{"tool" => "cone"} = tool_data, _grid_size) do
    cone(tool_data)
  end

  def compute(%{"tool" => "line"} = tool_data, _grid_size) do
    line(tool_data)
  end

  def compute(_tool_data, _grid_size), do: %{type: :none}

  # --- Shape functions (all coordinates in subpixel space) ---

  defp ruler(tool_data) do
    {sx, sy, cx, cy} = extract_coords(tool_data)
    seg = segment_geometry(sx, sy, cx, cy)
    Map.merge(seg, %{type: :ruler, distance: tool_data["distance"]})
  end

  defp ruler_path(tool_data, grid_size) do
    waypoints = tool_data["waypoints"] || []
    {cx, cy} = {to_int(tool_data["current_x"]), to_int(tool_data["current_y"])}

    all_points = waypoints ++ [{cx, cy}]

    {segments, _} =
      all_points
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map_reduce(0, fn [{x1, y1}, {x2, y2}], acc ->
        seg = segment_geometry(x1, y1, x2, y2)
        cumulative = acc + seg.length
        feet = Float.round(cumulative / grid_size * 5, 1)
        {Map.put(seg, :feet, feet), cumulative}
      end)

    %{type: :ruler_path, segments: segments}
  end

  defp segment_geometry(sx, sy, cx, cy) do
    dx = cx - sx
    dy = cy - sy
    length = round(:math.sqrt(dx * dx + dy * dy))
    angle = :math.atan2(dy, dx) * 180 / :math.pi()

    %{
      sx: sx,
      sy: sy,
      length: length,
      angle: angle,
      text_x: round((sx + cx) / 2),
      text_y: round((sy + cy) / 2)
    }
  end

  defp pointer(tool_data) do
    {_sx, _sy, cx, cy} = extract_coords(tool_data)
    %{type: :pointer, cx: cx, cy: cy}
  end

  defp circle(tool_data) do
    {sx, sy, cx, cy} = extract_coords(tool_data)
    radius = round(:math.sqrt((cx - sx) ** 2 + (cy - sy) ** 2))
    %{type: :circle, cx: sx, cy: sy, r: radius}
  end

  defp cone(tool_data) do
    {sx, sy, cx, cy} = extract_coords(tool_data)
    dx = cx - sx
    dy = cy - sy
    radius = :math.sqrt(dx * dx + dy * dy)
    angle = :math.atan2(dy, dx)
    spread = :math.pi() / 2

    %{
      type: :cone,
      sx: sx,
      sy: sy,
      x1: round(sx + radius * :math.cos(angle - spread / 2)),
      y1: round(sy + radius * :math.sin(angle - spread / 2)),
      x2: round(sx + radius * :math.cos(angle + spread / 2)),
      y2: round(sy + radius * :math.sin(angle + spread / 2)),
      radius: round(radius)
    }
  end

  defp line(tool_data) do
    {sx, sy, cx, cy} = extract_coords(tool_data)
    angle = :math.atan2(cy - sy, cx - sx)
    hw = GeometryMapper.to_subpixels(12)
    px = :math.cos(angle + :math.pi() / 2) * hw
    py = :math.sin(angle + :math.pi() / 2) * hw

    %{
      type: :line,
      corners: [
        {round(sx + px), round(sy + py)},
        {round(cx + px), round(cy + py)},
        {round(cx - px), round(cy - py)},
        {round(sx - px), round(sy - py)}
      ]
    }
  end

  # --- Grid cell computation (subpixel space) ---

  defp grid_cells(%{"tool" => tool} = tool_data, grid_size) do
    {sx, sy, cx, cy} = extract_coords(tool_data)

    cells =
      case tool do
        t when t in ~w(burst emanation) -> circle_affected_cells(sx, sy, cx, cy, grid_size)
        "cone" -> cone_affected_cells(sx, sy, cx, cy, grid_size)
        "line" -> line_affected_cells(sx, sy, cx, cy, grid_size)
        _ -> []
      end

    %{type: :grid_cells, cells: cells, cell_size: grid_size}
  end

  defp circle_affected_cells(sx, sy, cx, cy, cs) do
    radius = :math.sqrt((cx - sx) ** 2 + (cy - sy) ** 2)
    if radius < 1, do: [], else: do_circle_cells(sx, sy, radius, cs)
  end

  defp do_circle_cells(sx, sy, radius, cs) do
    min_col = floor((sx - radius) / cs)
    max_col = ceil((sx + radius) / cs)
    min_row = floor((sy - radius) / cs)
    max_row = ceil((sy + radius) / cs)

    for col <- min_col..(max_col - 1),
        row <- min_row..(max_row - 1),
        cell_within_radius?(sx, sy, col, row, cs, radius),
        do: {col, row}
  end

  defp cell_within_radius?(sx, sy, col, row, cs, radius) do
    near_x = clamp(sx, col * cs, (col + 1) * cs)
    near_y = clamp(sy, row * cs, (row + 1) * cs)
    dist = :math.sqrt((near_x - sx) ** 2 + (near_y - sy) ** 2)
    dist <= radius + 0.5
  end

  defp cone_affected_cells(sx, sy, cx, cy, cs) do
    radius = :math.sqrt((cx - sx) ** 2 + (cy - sy) ** 2)
    if radius < 1, do: [], else: do_cone_cells(sx, sy, cx, cy, radius, cs)
  end

  defp do_cone_cells(sx, sy, cx, cy, radius, cs) do
    angle = :math.atan2(cy - sy, cx - sx)
    half_spread = :math.pi() / 4

    min_col = floor((sx - radius) / cs)
    max_col = ceil((sx + radius) / cs)
    min_row = floor((sy - radius) / cs)
    max_row = ceil((sy + radius) / cs)

    for col <- min_col..(max_col - 1),
        row <- min_row..(max_row - 1),
        cell_within_radius?(sx, sy, col, row, cs, radius),
        cell_within_cone?(sx, sy, col, row, cs, angle, half_spread),
        do: {col, row}
  end

  defp cell_within_cone?(sx, sy, col, row, cs, angle, half_spread) do
    center_x = (col * cs + (col + 1) * cs) / 2
    center_y = (row * cs + (row + 1) * cs) / 2
    cell_angle = :math.atan2(center_y - sy, center_x - sx)
    diff = normalize_angle(cell_angle - angle)
    abs(diff) <= half_spread + 0.01
  end

  defp line_affected_cells(sx, sy, cx, cy, cs) do
    length = :math.sqrt((cx - sx) ** 2 + (cy - sy) ** 2)
    if length < 1, do: [], else: do_line_cells(sx, sy, cx, cy, cs)
  end

  defp do_line_cells(sx, sy, cx, cy, cs) do
    angle = :math.atan2(cy - sy, cx - sx)
    hw = cs / 2
    px = :math.cos(angle + :math.pi() / 2) * hw
    py = :math.sin(angle + :math.pi() / 2) * hw

    corners = [
      {sx + px, sy + py},
      {cx + px, cy + py},
      {cx - px, cy - py},
      {sx - px, sy - py}
    ]

    {xs, ys} = Enum.unzip(corners)
    min_col = floor(Enum.min(xs) / cs)
    max_col = ceil(Enum.max(xs) / cs)
    min_row = floor(Enum.min(ys) / cs)
    max_row = ceil(Enum.max(ys) / cs)

    for col <- min_col..(max_col - 1),
        row <- min_row..(max_row - 1),
        point_in_polygon?(
          (col * cs + (col + 1) * cs) / 2,
          (row * cs + (row + 1) * cs) / 2,
          corners
        ),
        do: {col, row}
  end

  defp point_in_polygon?(x, y, polygon) do
    polygon
    |> Enum.zip(rotate_list(polygon))
    |> Enum.reduce(false, fn {{xi, yi}, {xj, yj}}, inside ->
      if yi > y != yj > y and x < (xj - xi) * (y - yi) / (yj - yi) + xi do
        not inside
      else
        inside
      end
    end)
  end

  defp rotate_list([]), do: []
  defp rotate_list([h | t]), do: t ++ [h]

  # --- Helpers ---

  defp extract_coords(tool_data) do
    sx = to_int(tool_data["start_x"])
    sy = to_int(tool_data["start_y"])
    cx = to_int(tool_data["current_x"])
    cy = to_int(tool_data["current_y"])
    {sx, sy, cx, cy}
  end

  defp to_int(nil), do: 0
  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: round(v)

  defp clamp(val, min, max), do: max(min, min(max, val))

  @pi :math.pi()
  defp normalize_angle(angle) when angle > @pi, do: normalize_angle(angle - 2 * @pi)
  defp normalize_angle(angle) when angle < -@pi, do: normalize_angle(angle + 2 * @pi)
  defp normalize_angle(angle), do: angle
end
