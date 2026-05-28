defmodule PathMapperWeb.Scene.SceneComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Geometry.Object, as: GeometryObject

  @impl true
  def update(assigns, socket) do
    scene_changed = scene_was_updated?(socket, assigns)
    socket = assign(socket, assigns)

    socket =
      if scene_changed and has_viewport_geometry?(socket),
        do: build_map_geometry(socket),
        else: socket

    {:ok, socket}
  end

  defp has_viewport_geometry?(socket) do
    Map.has_key?(socket.assigns, :viewport_geometry)
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
    Adventure.get_scene_map(assigns.adventure, assigns.game_state.scene.index)
  end

  defp scene_was_updated?(
         %{assigns: %{game_state: %{scene: %{index: old_index}}}},
         %{game_state: %{scene: %{index: new_index}}}
       ) do
    old_index != new_index
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
    tokens_with_index = Enum.with_index(game_state.scene.tokens)

    if opts[:show_hidden] do
      tokens_with_index
    else
      Enum.filter(tokens_with_index, fn {token, _index} -> token.state !== "hidden" end)
    end
  end
end
