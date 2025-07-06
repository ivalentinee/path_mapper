defmodule PathMapperWeb.Scene.TokenComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Geometry.Object, as: GeometryObject

  @border_size 0.05
  @token_size_multiplier 1 - @border_size

  @impl true
  def update(assigns, socket) do
    %{size: size, x: x, y: y, drag_x: drag_x, drag_y: drag_y} = assigns.token

    token_geometry = build_token_geometry(assigns, size, x, y)
    dragged_token_geometry = build_token_geometry(assigns, size, drag_x, drag_y)

    socket =
      socket
      |> assign(assigns)
      |> assign(:token_geometry, token_geometry)
      |> assign(:dragged_token_geometry, dragged_token_geometry)

    {:ok, socket}
  end

  @impl true
  def handle_event("dragstart", %{"x" => mouse_offset_x, "y" => mouse_offset_y}, socket) do
    socket =
      socket
      |> assign(:mouse_offset_x, mouse_offset_x - socket.assigns.token_geometry.x)
      |> assign(:mouse_offset_y, mouse_offset_y - socket.assigns.token_geometry.y)
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

    socket =
      socket
      |> assign(:mouse_offset_x, nil)
      |> assign(:mouse_offset_y, nil)
      |> assign(:own_drag, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("drag", %{"x" => x, "y" => y, "id" => _id} = _event, socket) do
    if socket.assigns[:mouse_offset_x] do
      x = x - if socket.assigns[:mouse_offset_x], do: socket.assigns[:mouse_offset_x], else: 0
      y = y - if socket.assigns[:mouse_offset_y], do: socket.assigns[:mouse_offset_y], else: 0

      scaled_x = GeometryMapper.scale_back(x, socket.assigns.map_geometry)
      scaled_y = GeometryMapper.scale_back(y, socket.assigns.map_geometry)

      Game.run_action([:tokens, socket.assigns.index, :drag], {scaled_x, scaled_y, %{}})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def show_index(selected_token_index, token_index) when selected_token_index == token_index,
    do: true

  def show_index(:all, _token_index), do: true
  def show_index(_selected_token_index, _token_index), do: false

  def token_shape_style(token, token_geometry, transparent) do
    size = token_geometry.width * @token_size_multiplier
    radius = ceil(size / 2)
    border_width = ceil(size * @border_size)
    # NOTE: I have no idea why it works
    position_offset = border_width / 4

    opacity = if transparent, do: 0.5, else: 1

    style = %{
      "position" => "absolute",
      "left" => "#{token_geometry.x - position_offset}px",
      "top" => "#{token_geometry.y - position_offset}px",
      "border-radius" => "#{radius}px",
      "border" => if(no_owner?(token), do: "", else: "#{border_width}px solid #{token.color}"),
      "width" => "#{size}px",
      "height" => "#{size}px",
      "z-index" => 200,
      "opacity" => opacity
    }

    serialize_style(style)
  end

  def token_image_style(_token, token_geometry) do
    size = token_geometry.width * @token_size_multiplier

    style = %{
      "position" => "absolute",
      "left" => "0px",
      "top" => "0px",
      "width" => "#{size}px",
      "height" => "#{size}px"
    }

    serialize_style(style)
  end

  def token_state_style(token, token_geometry) do
    size = token_geometry.width
    radius = round(size / 2)

    border_width = ceil(size * @border_size)
    # NOTE: I have no idea why it works
    position_offset = border_width / 2
    opacity = if token.state == "alive", do: 0, else: 0.5

    style = %{
      "position" => "absolute",
      "left" => "#{-position_offset}px",
      "top" => "#{-position_offset}px",
      "border-radius" => "#{radius}px",
      "background" => token_state_color(token),
      "width" => "#{size}px",
      "height" => "#{size}px",
      "z-index" => 250,
      "opacity" => opacity
    }

    serialize_style(style)
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
      "dead" -> "#db5164"
      "unconscious" -> "#57d5ff"
      _ -> "white"
    end
  end

  defp no_owner?(token), do: token.data.owner == "none"
end
