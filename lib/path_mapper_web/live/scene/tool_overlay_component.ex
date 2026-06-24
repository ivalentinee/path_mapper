defmodule PathMapperWeb.Scene.ToolOverlayComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.MapTools
  alias PathMapper.MapTools.HitTest
  alias PathMapper.MapTools.Shapes
  alias PathMapper.MapTools.ToolConfig

  @drawing_tools ~w(fill rect draw_line draw_circle)

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns) |> assign_new(:own_tool, fn -> nil end)
    tool_cfg = ToolConfig.get(socket.assigns.active_tool)

    socket =
      socket
      |> assign(:tool_snap_mode, tool_cfg && tool_cfg.snap_mode)
      |> assign(:tool_interaction, tool_cfg && tool_cfg.interaction)
      |> assign(:tool_rmb, tool_cfg && tool_cfg.allowed_buttons)
      |> assign(:tool_path_mode, tool_cfg && tool_cfg.path_mode)

    {:ok, socket}
  end

  @impl true
  def handle_event("tool_draw", %{"mode" => "path"} = params, socket) do
    geo = socket.assigns.map_geometry
    grid_size_sp = GeometryMapper.to_subpixels(socket.assigns.grid_size)
    color = effective_color(params["tool"], socket.assigns)
    session_id = socket.assigns.session_id

    waypoints = convert_waypoints(params["waypoints"], geo)
    cx = GeometryMapper.scale_back(params["current_x"] || 0, geo)
    cy = GeometryMapper.scale_back(params["current_y"] || 0, geo)

    tool_data = %{
      "tool" => params["tool"] || "ruler",
      "mode" => "path",
      "waypoints" => waypoints,
      "current_x" => cx,
      "current_y" => cy,
      "grid_size" => grid_size_sp,
      "color" => color,
      "session_id" => session_id
    }

    MapTools.draw(session_id, tool_data)
    {:noreply, assign(socket, :own_tool, tool_data)}
  end

  @impl true
  def handle_event("tool_draw", params, socket) do
    geo = socket.assigns.map_geometry
    grid_size = socket.assigns.grid_size
    color = effective_color(params["tool"], socket.assigns)
    session_id = socket.assigns.session_id

    # Compute distance from raw screen-pixel params before subpixel conversion
    distance = compute_distance(params, grid_size, geo)

    tool_data =
      params
      |> Map.take(~w(tool mode start_x start_y current_x current_y))
      |> screen_to_subpixels(geo)
      |> Map.put("grid_size", GeometryMapper.to_subpixels(grid_size))
      |> Map.put("color", color)
      |> Map.put("distance", distance)
      |> Map.put("session_id", session_id)

    MapTools.draw(session_id, tool_data)
    {:noreply, assign(socket, :own_tool, tool_data)}
  end

  @impl true
  def handle_event("tool_clear", _, socket) do
    own_tool = socket.assigns.own_tool

    cond do
      own_tool && own_tool["tool"] in @drawing_tools ->
        commit_drawing(own_tool, socket.assigns)

      own_tool && own_tool["tool"] == "eraser" ->
        erase_at(own_tool, socket.assigns)

      true ->
        :ok
    end

    MapTools.clear(socket.assigns.session_id)
    {:noreply, assign(socket, :own_tool, nil)}
  end

  @impl true
  def handle_event("deselect_tool", _, socket) do
    send(self(), %{session_event: :deselect_tool})
    {:noreply, socket}
  end

  @impl true
  def handle_event("draw_commit", %{"tool" => "draw_line", "waypoints" => waypoints}, socket)
      when is_list(waypoints) and length(waypoints) >= 2 do
    geo = socket.assigns.map_geometry

    points =
      Enum.map(waypoints, fn [x, y] ->
        [
          GeometryMapper.from_subpixels(GeometryMapper.scale_back(x, geo)),
          GeometryMapper.from_subpixels(GeometryMapper.scale_back(y, geo))
        ]
      end)

    Game.run_action([:draw, :add], %{
      type: :line,
      color: socket.assigns[:draw_color] || "#8B4513",
      owner: socket.assigns[:draw_owner] || "GM",
      data: %{"points" => points, "width" => 2}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("draw_commit", %{"tool" => "text", "x" => x, "y" => y, "text" => text}, socket)
      when is_binary(text) and text != "" do
    geo = socket.assigns.map_geometry

    Game.run_action([:draw, :add], %{
      type: :text,
      color: socket.assigns[:draw_color] || "#8B4513",
      owner: socket.assigns[:draw_owner] || "GM",
      data: %{
        "x" => GeometryMapper.from_subpixels(GeometryMapper.scale_back(x, geo)),
        "y" => GeometryMapper.from_subpixels(GeometryMapper.scale_back(y, geo)),
        "text" => text,
        "font_size" => 14
      }
    })

    {:noreply, socket}
  end

  @impl true
  def handle_event("draw_commit", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("map_zoom", %{"delta" => delta}, socket) do
    send(self(), %{session_event: {:map_zoom, delta}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("map_pan", %{"dx" => dx, "dy" => dy}, socket) do
    send(self(), %{session_event: {:map_pan, {dx, dy}}})
    {:noreply, socket}
  end

  @coord_keys ~w(start_x start_y current_x current_y)

  defp screen_to_subpixels(params, geo) do
    Enum.reduce(@coord_keys, params, fn key, acc ->
      case acc[key] do
        v when is_number(v) -> Map.put(acc, key, GeometryMapper.scale_back(v, geo))
        _ -> acc
      end
    end)
  end

  defp convert_waypoints(waypoints, geo) when is_list(waypoints) do
    waypoints
    |> Enum.filter(&match?([_, _], &1))
    |> Enum.map(fn [x, y] ->
      {GeometryMapper.scale_back(x, geo), GeometryMapper.scale_back(y, geo)}
    end)
  end

  defp convert_waypoints(_, _geo), do: []

  defp compute_distance(params, grid_size, geo) do
    sx = GeometryMapper.scale_back(params["start_x"] || 0, geo)
    sy = GeometryMapper.scale_back(params["start_y"] || 0, geo)
    cx = GeometryMapper.scale_back(params["current_x"] || 0, geo)
    cy = GeometryMapper.scale_back(params["current_y"] || 0, geo)
    grid_size_sp = GeometryMapper.to_subpixels(grid_size)
    dx = cx - sx
    dy = cy - sy
    pixel_distance = :math.sqrt(dx * dx + dy * dy)
    grid_squares = pixel_distance / grid_size_sp
    feet = Float.round(grid_squares * 5, 1)
    format_distance(feet)
  end

  defp format_distance(feet) do
    gettext("%{distance}ft", distance: feet)
  end

  defp all_tool_draws(%{tool_draws: draws, own_tool: nil}), do: draws || %{}

  defp all_tool_draws(%{tool_draws: draws, own_tool: tool, session_id: sid}),
    do: Map.put(draws || %{}, sid, tool)

  # Function component: renders a single tool's SVG based on computed shape.
  # Shapes.compute returns subpixel integers; sp/2 converts to screen pixels.
  attr :tool, :map, required: true
  attr :map_geometry, :any, required: true
  attr :grid_size, :integer, required: true

  def tool_shape(%{tool: tool, map_geometry: geo, grid_size: grid_size} = assigns) do
    grid_size_sp = GeometryMapper.to_subpixels(grid_size)
    shape = Shapes.compute(tool, grid_size_sp)
    color = tool["color"] || "#808080"

    assigns =
      assigns
      |> assign(:shape, shape)
      |> assign(:color, color)
      |> assign(:geo, geo)

    render_shape(assigns)
  end

  defp sp(value, geo), do: GeometryMapper.scale_to(value, geo)

  defp render_shape(%{shape: %{type: :ruler}} = assigns) do
    geo = assigns.geo
    shape = assigns.shape

    assigns =
      assigns
      |> assign(:x, sp(shape.sx, geo))
      |> assign(:y, sp(shape.sy, geo) - 12)
      |> assign(:w, sp(shape.length, geo))
      |> assign(:h, 24)
      |> assign(:rx, 4)
      |> assign(
        :transform,
        "rotate(#{Float.round(shape.angle * 1.0, 1)}, #{sp(shape.sx, geo)}, #{sp(shape.sy, geo)})"
      )
      |> assign(:tx, sp(shape.text_x, geo))
      |> assign(:ty, sp(shape.text_y, geo) + 5)
      |> assign(:distance, shape.distance)

    ~H"""
    <rect
      x={@x}
      y={@y}
      width={@w}
      height={@h}
      rx={@rx}
      transform={@transform}
      fill="rgba(40, 40, 60, 0.7)"
      stroke={@color}
      stroke-width="1.5"
    />
    <%= if @distance do %>
      <text
        x={@tx}
        y={@ty}
        fill="white"
        font-size="14px"
        font-weight="bold"
        text-anchor="middle"
        pointer-events="none"
      >
        {@distance}
      </text>
    <% end %>
    """
  end

  defp render_shape(%{shape: %{type: :ruler_path}} = assigns) do
    geo = assigns.geo

    segments =
      Enum.map(assigns.shape.segments, fn seg ->
        %{
          x: sp(seg.sx, geo),
          y: sp(seg.sy, geo) - 12,
          w: sp(seg.length, geo),
          h: 24,
          rx: 4,
          transform:
            "rotate(#{Float.round(seg.angle * 1.0, 1)}, #{sp(seg.sx, geo)}, #{sp(seg.sy, geo)})",
          tx: sp(seg.text_x, geo),
          ty: sp(seg.text_y, geo) + 5,
          distance: format_distance(seg.feet)
        }
      end)

    assigns = assign(assigns, :segments, segments)

    ~H"""
    <%= for seg <- @segments do %>
      <rect
        x={seg.x}
        y={seg.y}
        width={seg.w}
        height={seg.h}
        rx={seg.rx}
        transform={seg.transform}
        fill="rgba(40, 40, 60, 0.7)"
        stroke={@color}
        stroke-width="1.5"
      />
      <text
        x={seg.tx}
        y={seg.ty}
        fill="white"
        font-size="14px"
        font-weight="bold"
        text-anchor="middle"
        pointer-events="none"
      >
        {seg.distance}
      </text>
    <% end %>
    """
  end

  defp render_shape(%{shape: %{type: :pointer}} = assigns) do
    geo = assigns.geo

    assigns =
      assigns
      |> assign(:cx, sp(assigns.shape.cx, geo))
      |> assign(:cy, sp(assigns.shape.cy, geo))

    ~H"""
    <circle cx={@cx} cy={@cy} r="8" fill={@color} fill-opacity="0.8" stroke="white" stroke-width="2" />
    """
  end

  defp render_shape(%{shape: %{type: :circle}} = assigns) do
    geo = assigns.geo
    shape = assigns.shape

    assigns =
      assigns
      |> assign(:cx, sp(shape.cx, geo))
      |> assign(:cy, sp(shape.cy, geo))
      |> assign(:r, sp(shape.r, geo))

    ~H"""
    <circle
      cx={@cx}
      cy={@cy}
      r={@r}
      fill={@color}
      fill-opacity="0.2"
      stroke={@color}
      stroke-opacity="0.8"
      stroke-width="2"
    />
    """
  end

  defp render_shape(%{shape: %{type: :cone}} = assigns) do
    geo = assigns.geo
    shape = assigns.shape
    r = sp(shape.radius, geo)

    d =
      "M #{sp(shape.sx, geo)} #{sp(shape.sy, geo)} " <>
        "L #{sp(shape.x1, geo)} #{sp(shape.y1, geo)} " <>
        "A #{r} #{r} 0 0 1 #{sp(shape.x2, geo)} #{sp(shape.y2, geo)} Z"

    assigns = assign(assigns, :d, d)

    ~H"""
    <path
      d={@d}
      fill={@color}
      fill-opacity="0.2"
      stroke={@color}
      stroke-opacity="0.8"
      stroke-width="2"
    />
    """
  end

  defp render_shape(%{shape: %{type: :line}} = assigns) do
    geo = assigns.geo

    points =
      assigns.shape.corners
      |> Enum.map_join(" ", fn {x, y} -> "#{sp(x, geo)},#{sp(y, geo)}" end)

    assigns = assign(assigns, :points, points)

    ~H"""
    <polygon
      points={@points}
      fill={@color}
      fill-opacity="0.2"
      stroke={@color}
      stroke-opacity="0.8"
      stroke-width="2"
    />
    """
  end

  defp render_shape(%{shape: %{type: :draw_line_preview}} = assigns) do
    geo = assigns.geo

    points =
      assigns.shape.points
      |> Enum.map_join(" ", fn {x, y} -> "#{sp(x, geo)},#{sp(y, geo)}" end)

    assigns = assign(assigns, :points, points)

    ~H"""
    <polyline
      points={@points}
      stroke={@color}
      stroke-width="2"
      stroke-dasharray="6,4"
      fill="none"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
    """
  end

  defp render_shape(%{shape: %{type: :grid_cells, cells: cells}} = assigns) when cells != [] do
    geo = assigns.geo
    cs = assigns.shape.cell_size

    d =
      Enum.map_join(cells, "", fn {col, row} ->
        x = sp(col * cs, geo)
        y = sp(row * cs, geo)
        gs = sp(cs, geo)
        "M#{x} #{y}h#{gs}v#{gs}h-#{gs}Z"
      end)

    assigns = assign(assigns, :d, d)

    ~H"""
    <path
      d={@d}
      fill={@color}
      fill-opacity="0.3"
      stroke={@color}
      stroke-opacity="0.6"
      stroke-width="1"
    />
    """
  end

  defp render_shape(assigns) do
    ~H""
  end

  defp effective_color(tool, assigns) when tool in @drawing_tools do
    assigns[:draw_color] || "#8B4513"
  end

  defp effective_color(_tool, assigns), do: assigns.tool_color

  defp commit_drawing(%{"tool" => "fill"} = tool, assigns) do
    grid_size_sp = GeometryMapper.to_subpixels(assigns.grid_size)
    sx = to_int(tool["start_x"])
    sy = to_int(tool["start_y"])

    Game.run_action([:draw, :add], %{
      type: :fill,
      color: tool["color"],
      owner: assigns[:draw_owner] || "GM",
      data: %{"x" => div(sx, grid_size_sp), "y" => div(sy, grid_size_sp)}
    })
  end

  defp commit_drawing(%{"tool" => "rect"} = tool, assigns) do
    grid_size_sp = GeometryMapper.to_subpixels(assigns.grid_size)
    sx = to_int(tool["start_x"])
    sy = to_int(tool["start_y"])
    cx = to_int(tool["current_x"])
    cy = to_int(tool["current_y"])
    filled = tool["mode"] == "grid"

    Game.run_action([:draw, :add], %{
      type: :rect,
      color: tool["color"],
      owner: assigns[:draw_owner] || "GM",
      data: %{
        "x1" => div(sx, grid_size_sp),
        "y1" => div(sy, grid_size_sp),
        "x2" => div(cx, grid_size_sp),
        "y2" => div(cy, grid_size_sp),
        "filled" => filled
      }
    })
  end

  defp commit_drawing(%{"tool" => "draw_circle"} = tool, assigns) do
    sx = to_int(tool["start_x"])
    sy = to_int(tool["start_y"])
    cx = to_int(tool["current_x"])
    cy = to_int(tool["current_y"])
    radius = :math.sqrt((cx - sx) * (cx - sx) + (cy - sy) * (cy - sy))
    filled = tool["mode"] == "grid"

    Game.run_action([:draw, :add], %{
      type: :circle,
      color: tool["color"],
      owner: assigns[:draw_owner] || "GM",
      data: %{
        "cx" => GeometryMapper.from_subpixels(sx),
        "cy" => GeometryMapper.from_subpixels(sy),
        "radius" => GeometryMapper.from_subpixels(round(radius)),
        "filled" => filled
      }
    })
  end

  defp commit_drawing(_, _), do: :ok

  defp erase_at(tool, assigns) do
    # start_x/start_y are already in subpixels (converted by screen_to_subpixels in tool_draw)
    cx = to_int(tool["start_x"])
    cy = to_int(tool["start_y"])
    drawn_elements = assigns[:drawn_elements] || []
    grid_size = assigns.grid_size

    case HitTest.find(drawn_elements, cx, cy, grid_size) do
      %{id: id} ->
        Game.run_action([:draw, :remove], %{id: id, owner: assigns[:draw_owner] || "GM"})

      nil ->
        :ok
    end
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: round(v)
  defp to_int(_), do: 0
end
