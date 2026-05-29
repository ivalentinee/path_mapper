defmodule PathMapperWeb.Scene.TokenComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Geometry.Object, as: GeometryObject

  require PathMapper.TokenStates
  import PathMapper.TokenStates, only: [states: 0]

  embed_templates "token_context_menu*"

  @border_size 0.05

  @impl true
  def update(%{close_context_menu: true}, socket) do
    {:ok, assign(socket, context_menu: nil)}
  end

  def update(assigns, socket) do
    %{size: size, x: x, y: y, drag_x: drag_x, drag_y: drag_y} = assigns.token

    token_geometry = build_token_geometry(assigns, size, x, y)
    dragged_token_geometry = build_token_geometry(assigns, size, drag_x, drag_y)
    grid_line_padding = grid_line_padding(assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign(:token_geometry, token_geometry)
      |> assign(:dragged_token_geometry, dragged_token_geometry)
      |> assign(:grid_line_padding, grid_line_padding)

    {:ok, socket}
  end

  @impl true
  def handle_event("dragstart", %{"x" => mouse_x, "y" => mouse_y}, socket) do
    map_geo = socket.assigns.map_geometry
    token_geo = socket.assigns.token_geometry

    {token_viewport_x, token_viewport_y} =
      GeometryMapper.map_screen_to_viewport(token_geo.x, token_geo.y, map_geo)

    socket =
      socket
      |> assign(:mouse_offset_x, mouse_x - token_viewport_x)
      |> assign(:mouse_offset_y, mouse_y - token_viewport_y)
      |> assign(:own_drag, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("dragend", _event, socket) do
    snap_to_grid = socket.assigns.scene_state.snap_to_grid

    Game.run_action(
      [:tokens, socket.assigns.index, :move],
      {socket.assigns.token.drag_x, socket.assigns.token.drag_y, %{snap: snap_to_grid}}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("drag", %{"x" => x, "y" => y, "id" => _id} = _event, socket) do
    if socket.assigns[:mouse_offset_x] do
      viewport_x = x - socket.assigns.mouse_offset_x
      viewport_y = y - socket.assigns.mouse_offset_y

      {map_x, map_y} =
        GeometryMapper.viewport_to_map(viewport_x, viewport_y, socket.assigns.map_geometry)

      Game.run_action([:tokens, socket.assigns.index, :drag], {map_x, map_y, %{}})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("context_menu", %{"x" => x, "y" => y}, socket) do
    if can_manage_token?(socket.assigns) do
      send(self(), {:close_all_context_menus, socket.assigns.id})
      {:noreply, assign(socket, context_menu: %{x: x, y: y})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_context_menu", _, socket) do
    {:noreply, assign(socket, context_menu: nil)}
  end

  @impl true
  def handle_event("context_set_state", %{"state" => state}, socket)
      when state in states() do
    Game.run_action([:tokens, socket.assigns.index, :set_state], state)
    {:noreply, assign(socket, context_menu: nil)}
  end

  @impl true
  def handle_event("context_delete", _, socket) do
    Game.run_action([:tokens, :delete], socket.assigns.index)
    {:noreply, assign(socket, context_menu: nil)}
  end

  @impl true
  def handle_event(
        "token_select",
        %{"index" => index},
        %{assigns: %{opts: %{manage_tokens: true}}} = socket
      ) do
    with_parsed_index(index, fn index_number ->
      send(
        self(),
        %{left_panel_update: %{left_panel_select: ["left-panel", "tokens", index_number + 1]}}
      )
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("token_select", _, socket), do: {:noreply, socket}

  defp can_manage_token?(%{opts: %{manage_tokens: true}}), do: true

  defp can_manage_token?(%{my_player_name: name, token: token}) when is_binary(name) do
    token.data.owner == name
  end

  defp can_manage_token?(_), do: false

  def show_index(selected_token_index, token_index) when selected_token_index == token_index,
    do: true

  def show_index(:all, _token_index), do: true
  def show_index(_selected_token_index, _token_index), do: false

  def token_container_style(token_geometry, grid_line_padding, transparent) do
    size = token_geometry.width
    opacity = if transparent, do: 0.5, else: 1

    serialize_style(%{
      "position" => "absolute",
      "left" => "#{token_geometry.x}px",
      "top" => "#{token_geometry.y}px",
      "box-sizing" => "border-box",
      "padding" => "#{grid_line_padding}px",
      "width" => "#{size}px",
      "height" => "#{size}px",
      "z-index" => 200,
      "opacity" => opacity
    })
  end

  def token_shape_style do
    serialize_style(%{
      "position" => "relative",
      "width" => "100%",
      "height" => "100%",
      "border-radius" => "50%",
      "overflow" => "hidden"
    })
  end

  def token_border_style(token, token_geometry) do
    size = token_geometry.width
    border_width = ceil(size * @border_size)

    if no_owner?(token) do
      "display: none;"
    else
      serialize_style(%{
        "position" => "absolute",
        "left" => "0px",
        "top" => "0px",
        "width" => "100%",
        "height" => "100%",
        "border-radius" => "50%",
        "box-shadow" => "inset 0 0 0 #{border_width}px #{token.color}",
        "z-index" => 210,
        "pointer-events" => "none"
      })
    end
  end

  def token_image_style do
    serialize_style(%{
      "width" => "100%",
      "height" => "100%",
      "display" => "block"
    })
  end

  def token_state_style(%{state: "hidden"}) do
    serialize_style(%{
      "position" => "absolute",
      "left" => "0px",
      "top" => "0px",
      "border-radius" => "50%",
      "background" =>
        "repeating-linear-gradient(-45deg, transparent, transparent 4px, rgba(0,0,0,0.7) 4px, rgba(0,0,0,0.7) 8px)",
      "width" => "100%",
      "height" => "100%",
      "z-index" => 250,
      "opacity" => 0.8
    })
  end

  def token_state_style(token) do
    opacity = if token.state == "alive", do: 0, else: 0.5

    serialize_style(%{
      "position" => "absolute",
      "left" => "0px",
      "top" => "0px",
      "border-radius" => "50%",
      "background" => token_state_color(token),
      "width" => "100%",
      "height" => "100%",
      "z-index" => 250,
      "opacity" => opacity
    })
  end

  defp build_token_geometry(assigns, size, x, y) when is_number(x) and is_number(y) do
    GeometryMapper.scale_to(
      %GeometryObject{width: size, height: size, x: x, y: y},
      assigns.map_geometry
    )
  end

  defp build_token_geometry(_assigns, _size, _x, _y), do: nil

  defp token_state_color(token) do
    case token.state do
      "dead" -> "#c93a4e"
      "unconscious" -> "#4a9ec7"
      "hidden" -> "#1a1528"
      _ -> "white"
    end
  end

  defp grid_line_padding(%{grid_line_width: line_width, map_geometry: map_geometry}) do
    GeometryMapper.scale_to(
      GeometryMapper.to_subpixels(ceil(line_width / 2.0)),
      map_geometry
    )
  end

  defp no_owner?(token), do: token.data.owner == "none"
end
