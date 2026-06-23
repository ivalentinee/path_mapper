defmodule PathMapperWeb.Scene.DrawnMapComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  @type_order %{fill: 0, rect: 0, line: 1, circle: 1, text: 2}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :sorted_elements, sort_for_render(assigns.drawn_elements))

    ~H"""
    <svg class="drawn-map" style="width: 100%; height: 100%;">
      <%= for element <- @sorted_elements do %>
        <.drawn_element element={element} geometry={@geometry} grid_size={@grid_size} />
      <% end %>
    </svg>
    """
  end

  # Stable sort: fills/rects (0) → lines/circles (1) → text (2)
  defp sort_for_render(elements) do
    Enum.sort_by(elements, fn el -> @type_order[el.type] || 0 end)
  end

  defp drawn_element(%{element: %{type: :fill}} = assigns) do
    ~H"""
    <rect
      x={sp(@element.data["x"] * @grid_size, @geometry)}
      y={sp(@element.data["y"] * @grid_size, @geometry)}
      width={sp(@grid_size, @geometry)}
      height={sp(@grid_size, @geometry)}
      fill={@element.color}
    />
    """
  end

  defp drawn_element(%{element: %{type: :rect}} = assigns) do
    ~H"""
    <rect
      x={sp(min(@element.data["x1"], @element.data["x2"]) * @grid_size, @geometry)}
      y={sp(min(@element.data["y1"], @element.data["y2"]) * @grid_size, @geometry)}
      width={sp((abs(@element.data["x2"] - @element.data["x1"]) + 1) * @grid_size, @geometry)}
      height={sp((abs(@element.data["y2"] - @element.data["y1"]) + 1) * @grid_size, @geometry)}
      fill={@element.color}
    />
    """
  end

  defp drawn_element(%{element: %{type: :line}} = assigns) do
    ~H"""
    <polyline
      points={points_string(@element.data["points"], @geometry)}
      stroke={@element.color}
      stroke-width={sp(@element.data["width"] || 2, @geometry)}
      fill="none"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
    """
  end

  defp drawn_element(%{element: %{type: :circle}} = assigns) do
    ~H"""
    <circle
      cx={sp(@element.data["cx"], @geometry)}
      cy={sp(@element.data["cy"], @geometry)}
      r={sp(@element.data["radius"], @geometry)}
      stroke={@element.color}
      stroke-width={sp(@element.data["width"] || 2, @geometry)}
      fill="none"
    />
    """
  end

  defp drawn_element(%{element: %{type: :text}} = assigns) do
    ~H"""
    <text
      x={sp(@element.data["x"], @geometry)}
      y={sp(@element.data["y"], @geometry)}
      fill={@element.color}
      font-size="14px"
      font-family="sans-serif"
    >
      {@element.data["text"]}
    </text>
    """
  end

  # Coordinates are in map pixels, use scale_map_pixel (not scale_to)
  defp sp(value, geometry), do: GeometryMapper.scale_map_pixel(value, geometry)

  defp points_string(points, geometry) when is_list(points) do
    Enum.map_join(points, " ", fn [x, y] -> "#{sp(x, geometry)},#{sp(y, geometry)}" end)
  end

  defp points_string(_, _), do: ""
end
