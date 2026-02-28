defmodule PathMapperWeb.Scene.SceneComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Geometry.Object, as: GeometryObject

  @impl true
  def update(assigns, socket) do
    socket =
      if scene_was_updated?(socket, assigns),
        do: build_map_geometry(assign(socket, assigns)),
        else: assign(socket, assigns)

    {:ok, socket}
  end

  @impl true
  def handle_event("geometry", %{"width" => viewport_width, "height" => viewport_height}, socket) do
    viewport_geometry = GeometryObject.build(viewport_width, viewport_height)

    socket =
      socket
      |> assign(:viewport_geometry, viewport_geometry)
      |> build_map_geometry()

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

  defp scene_was_updated?(
         %{assigns: %{game_state: %{scene: scene}}} = _socket,
         %{game_state: %{scene: new_scene}} = _new_assigns
       ) do
    scene.index != new_scene.index
  end

  defp scene_was_updated?(_socket, _new_assigns), do: false

  defp build_map_geometry(socket) do
    viewport_geometry = socket.assigns.viewport_geometry
    map = get_map(socket.assigns)

    map_geometry =
      map
      |> GeometryObject.build()
      |> GeometryMapper.fit_to_viewport(viewport_geometry)
      |> GeometryMapper.center(viewport_geometry)

    socket
    |> assign(:map_geometry, map_geometry)
    |> assign(:grid_size, map.grid_size)
  end

  defp visible_tokens(game_state, opts) do
    if opts[:show_hidden] do
      game_state.scene.tokens
    else
      Enum.filter(game_state.scene.tokens, fn token -> token.state !== "hidden" end)
    end
  end
end
