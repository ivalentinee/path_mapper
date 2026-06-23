defmodule PathMapperWeb.Scene.SceneComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game
  alias PathMapper.Game.Palette
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Geometry.Object, as: GeometryObject
  alias PathMapperWeb.Scene.GridComponent
  alias PathMapperWeb.Scene.MapComponent
  alias PathMapperWeb.Scene.SceneState

  @impl true
  def update(assigns, socket) do
    scene_changed = scene_was_updated?(socket, assigns)
    zoom_changed = zoom_or_pan_changed?(socket, assigns)
    socket = assign(socket, assigns)

    socket =
      cond do
        scene_changed and has_viewport_geometry?(socket) ->
          scene = SceneState.reset_zoom(socket.assigns.scene)
          socket |> assign(:scene, scene) |> build_map_geometry()

        zoom_changed and has_viewport_geometry?(socket) ->
          build_map_geometry(socket)

        true ->
          socket
      end

    {:ok, socket}
  end

  defp has_viewport_geometry?(socket) do
    Map.has_key?(socket.assigns, :viewport_geometry)
  end

  # Guard: reject all object events in player view
  def handle_event("object_" <> _, _, %{assigns: %{opts: opts}} = socket)
      when not is_map_key(opts, :manage_objects) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("object_drag", %{"index" => index, "screen_x" => sx, "screen_y" => sy}, socket) do
    geo = socket.assigns.map_geometry
    map_x = GeometryMapper.scale_back(sx, geo)
    map_y = GeometryMapper.scale_back(sy, geo)
    Game.run_action([:map_objects, index, :drag], {map_x, map_y})
    {:noreply, socket}
  end

  @impl true
  def handle_event("object_move", %{"index" => index, "screen_x" => sx, "screen_y" => sy}, socket) do
    geo = socket.assigns.map_geometry
    map_x = GeometryMapper.scale_back(sx, geo)
    map_y = GeometryMapper.scale_back(sy, geo)
    Game.run_action([:map_objects, index, :move], {map_x, map_y})
    {:noreply, socket}
  end

  @impl true
  def handle_event("object_context_menu", %{"index" => index, "x" => x, "y" => y}, socket) do
    {:noreply, assign(socket, object_context_menu: %{index: index, x: x, y: y})}
  end

  @impl true
  def handle_event("close_object_context_menu", _, socket) do
    {:noreply, assign(socket, object_context_menu: nil)}
  end

  @impl true
  def handle_event("object_toggle_lock", %{"index" => index_str}, socket) do
    with_parsed_index(index_str, &Game.run_action([:map_objects, &1, :toggle_lock], nil))
    {:noreply, assign(socket, object_context_menu: nil)}
  end

  @impl true
  def handle_event("object_toggle_show", %{"index" => index_str}, socket) do
    with_parsed_index(index_str, &Game.run_action([:map_objects, &1, :toggle_show], nil))
    {:noreply, assign(socket, object_context_menu: nil)}
  end

  @impl true
  def handle_event("object_reset_position", %{"index" => index_str}, socket) do
    with_parsed_index(index_str, &Game.run_action([:map_objects, &1, :reset_position], nil))
    {:noreply, assign(socket, object_context_menu: nil)}
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

  defp tool_color(assigns) do
    cond do
      assigns[:opts][:manage_tokens] ->
        "#db0909"

      assigns[:opts][:my_player_name] ->
        Palette.resolve(assigns[:opts][:my_player_name]) || "#808080"

      true ->
        "#808080"
    end
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
    scene = assigns.game_state.scene

    if scene.custom do
      %{width: scene.map.width, height: scene.map.height, grid_size: scene.map.grid_size}
    else
      Adventure.get_scene_map(assigns.adventure, scene.index)
    end
  end

  defp scene_was_updated?(
         %{assigns: %{game_state: %{scene: %{index: old_index}}}},
         %{game_state: %{scene: %{index: new_index}}}
       ) do
    old_index != new_index
  end

  defp scene_was_updated?(_socket, _new_assigns), do: false

  defp zoom_or_pan_changed?(
         %{assigns: %{scene: %{zoom: old_z, pan: old_p}}},
         %{scene: %{zoom: new_z, pan: new_p}}
       ),
       do: old_z != new_z or old_p != new_p

  defp zoom_or_pan_changed?(_, _), do: false

  defp build_map_geometry(socket) do
    viewport_geometry = socket.assigns.viewport_geometry
    map = get_map(socket.assigns)
    zoom = socket.assigns.scene.zoom
    {pan_x, pan_y} = socket.assigns.scene.pan

    map_geometry =
      map
      |> GeometryObject.build()
      |> GeometryMapper.fit_to_viewport(viewport_geometry)
      |> apply_zoom(zoom)
      |> apply_pan(pan_x, pan_y, viewport_geometry)

    socket
    |> assign(:map_geometry, map_geometry)
    |> assign(:grid_size, map.grid_size)
  end

  defp apply_zoom(%GeometryObject{} = geo, zoom) do
    %{geo | scale: geo.scale / zoom, width: geo.width * zoom, height: geo.height * zoom}
  end

  defp apply_pan(%GeometryObject{} = geo, pan_x, pan_y, viewport) do
    geo
    |> apply_axis(:x, :width, pan_x, viewport.width)
    |> apply_axis(:y, :height, pan_y, viewport.height)
  end

  defp apply_axis(geo, pos_key, size_key, pan, viewport_size) do
    map_size = Map.get(geo, size_key)

    if map_size <= viewport_size do
      Map.put(geo, pos_key, floor((viewport_size - map_size) / 2))
    else
      min_pan = viewport_size - map_size
      clamped = pan |> max(min_pan) |> min(0)
      Map.put(geo, pos_key, round(clamped))
    end
  end

  defp visible_tokens(game_state, opts) do
    tokens_with_index = Enum.with_index(game_state.scene.tokens)

    cond do
      opts[:show_hidden] ->
        tokens_with_index

      opts[:my_player_name] ->
        Enum.filter(tokens_with_index, fn {token, _index} ->
          token.state !== "hidden" or token.owner == opts[:my_player_name]
        end)

      true ->
        Enum.filter(tokens_with_index, fn {token, _index} -> token.state !== "hidden" end)
    end
  end

  defp visible_objects(adventure, game_state, opts) do
    adventure_map = Adventure.get_scene_map(adventure, game_state.scene.index)
    adventure_objects = if adventure_map, do: adventure_map.map_objects || [], else: []

    state_layers = game_state.scene.map.layers

    game_state.scene.map.map_objects
    |> Enum.map(fn obj_state ->
      adv_obj = Enum.at(adventure_objects, obj_state.index)
      layer_state = Enum.find(state_layers, &(&1.index == obj_state.layer_index))
      {adv_obj, obj_state, layer_state}
    end)
    |> Enum.reject(fn {adv, _, layer} -> is_nil(adv) or is_nil(layer) end)
    |> Enum.filter(fn {_, obj_state, layer_state} ->
      if opts[:show_hidden] do
        true
      else
        layer_state.show and obj_state.show
      end
    end)
  end

  defp object_style(obj, obj_state, layer_state, map_geometry, opts) do
    x = GeometryMapper.scale_to(obj_state.drag_x || obj_state.x, map_geometry)
    y = GeometryMapper.scale_to(obj_state.drag_y || obj_state.y, map_geometry)
    w = GeometryMapper.scale_map_pixel(obj.width, map_geometry)
    h = GeometryMapper.scale_map_pixel(obj.height, map_geometry)

    hidden = !layer_state.show or !obj_state.show

    opacity =
      if hidden and opts[:show_hidden] do
        "0.3"
      else
        "1"
      end

    serialize_style(%{
      "position" => "absolute",
      "left" => "#{x}px",
      "top" => "#{y}px",
      "width" => "#{w}px",
      "height" => "#{h}px",
      "opacity" => opacity,
      "z-index" => 50
    })
  end
end
