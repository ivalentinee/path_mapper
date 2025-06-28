defmodule PathMapperWeb.Scene.SceneComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Geometry.Object, as: GeometryObject

  @impl true
  def handle_event("geometry", %{"width" => viewport_width, "height" => viewport_height}, socket) do
    viewport_geometry = GeometryObject.build(viewport_width, viewport_height)
    map = get_map(socket.assigns)

    map_geometry =
      map
      |> GeometryObject.build()
      |> GeometryMapper.fit_to_viewport(viewport_geometry)
      |> GeometryMapper.center(viewport_geometry)

    socket =
      socket
      |> assign(:viewport_geometry, viewport_geometry)
      |> assign(:map_geometry, map_geometry)
      |> assign(:grid_size, map.grid_size)

    {:noreply, socket}
  end

  def map_style(geometry) do
    style = %{
      position: "absolute",
      left: "#{geometry.x}px",
      top: "#{geometry.y}px",
      width: "#{geometry.width}px",
      height: "#{geometry.height}px"
    }

    serialize_style(style)
  end

  def has_geometry?(assigns) when is_map(assigns) do
    Map.get(assigns, :map_geometry) && Map.get(assigns, :viewport_geometry)
  end

  defp get_map(assigns) do
    assigns.adventure
    |> Map.get(:scenes)
    |> Enum.at(assigns.game_state.scene.index)
    |> Map.get(:map)
  end
end
