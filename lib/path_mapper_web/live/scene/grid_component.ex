defmodule PathMapperWeb.Scene.GridComponent do
  use Phoenix.Component

  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  attr :width, :integer, required: true
  attr :height, :integer, required: true
  attr :grid_size, :integer, required: true
  attr :grid_line_width, :integer, required: true
  attr :geometry, :any, required: true
  attr :style, :string, required: true

  def svg_grid(assigns) do
    assigns =
      assigns
      |> assign(:cols, div(assigns.width, assigns.grid_size))
      |> assign(:rows, div(assigns.height, assigns.grid_size))

    ~H"""
    <div class="grid-container" style={@style}>
      <svg style="width: 100%; height: 100%;">
        <%= if @cols > 1 do %>
          <%= for col <- 1..(@cols - 1) do %>
            <line
              x1={sp(col * @grid_size, @geometry)}
              y1="0"
              x2={sp(col * @grid_size, @geometry)}
              y2={sp(@height, @geometry)}
              stroke="rgba(255, 255, 255, 0.3)"
              stroke-width={@grid_line_width}
            />
          <% end %>
        <% end %>
        <%= if @rows > 1 do %>
          <%= for row <- 1..(@rows - 1) do %>
            <line
              x1="0"
              y1={sp(row * @grid_size, @geometry)}
              x2={sp(@width, @geometry)}
              y2={sp(row * @grid_size, @geometry)}
              stroke="rgba(255, 255, 255, 0.3)"
              stroke-width={@grid_line_width}
            />
          <% end %>
        <% end %>
      </svg>
    </div>
    """
  end

  defp sp(value, geometry), do: GeometryMapper.scale_map_pixel(value, geometry)
end
