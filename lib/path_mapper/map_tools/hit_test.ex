defmodule PathMapper.MapTools.HitTest do
  @moduledoc false

  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  @type_order %{text: 2, line: 1, circle: 1, rect: 0, fill: 0}
  @click_threshold_px 10

  def find(drawn_elements, click_x_sp, click_y_sp, grid_size) when is_list(drawn_elements) do
    threshold = GeometryMapper.to_subpixels(@click_threshold_px)
    grid_size_sp = GeometryMapper.to_subpixels(grid_size)

    drawn_elements
    |> Enum.reverse()
    |> Enum.sort_by(fn el -> -(@type_order[el.type] || 0) end)
    |> Enum.find(fn el -> hits?(el, click_x_sp, click_y_sp, grid_size_sp, threshold) end)
  end

  defp hits?(%{type: :fill, data: data}, cx, cy, grid_size_sp, _threshold) do
    cell_x = data["x"] * grid_size_sp
    cell_y = data["y"] * grid_size_sp
    cx >= cell_x and cx < cell_x + grid_size_sp and cy >= cell_y and cy < cell_y + grid_size_sp
  end

  defp hits?(%{type: :rect, data: data}, cx, cy, grid_size_sp, _threshold) do
    x1 = min(data["x1"], data["x2"]) * grid_size_sp
    y1 = min(data["y1"], data["y2"]) * grid_size_sp
    x2 = (max(data["x1"], data["x2"]) + 1) * grid_size_sp
    y2 = (max(data["y1"], data["y2"]) + 1) * grid_size_sp
    cx >= x1 and cx < x2 and cy >= y1 and cy < y2
  end

  defp hits?(%{type: :line, data: data}, cx, cy, _grid_size_sp, threshold) do
    points = data["points"] || []

    points_sp =
      Enum.map(points, fn [x, y] ->
        {GeometryMapper.to_subpixels(x), GeometryMapper.to_subpixels(y)}
      end)

    points_sp
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [{x1, y1}, {x2, y2}] ->
      point_to_segment_distance(cx, cy, x1, y1, x2, y2) <= threshold
    end)
  end

  defp hits?(%{type: :circle, data: data}, cx, cy, _grid_size_sp, threshold) do
    center_x = GeometryMapper.to_subpixels(data["cx"])
    center_y = GeometryMapper.to_subpixels(data["cy"])
    radius = GeometryMapper.to_subpixels(data["radius"])
    dx = cx - center_x
    dy = cy - center_y
    distance = :math.sqrt(dx * dx + dy * dy)
    abs(distance - radius) <= threshold
  end

  defp hits?(%{type: :text, data: data}, cx, cy, _grid_size_sp, threshold) do
    tx = GeometryMapper.to_subpixels(data["x"])
    ty = GeometryMapper.to_subpixels(data["y"])
    abs(cx - tx) <= threshold * 3 and abs(cy - ty) <= threshold
  end

  defp hits?(_, _, _, _, _), do: false

  defp point_to_segment_distance(px, py, x1, y1, x2, y2) do
    dx = x2 - x1
    dy = y2 - y1
    len_sq = dx * dx + dy * dy

    if len_sq == 0 do
      :math.sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1))
    else
      t = max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / len_sq))
      proj_x = x1 + t * dx
      proj_y = y1 + t * dy
      :math.sqrt((px - proj_x) * (px - proj_x) + (py - proj_y) * (py - proj_y))
    end
  end
end
