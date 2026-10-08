defmodule PathMapperWeb.Scene.SceneComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game
  alias PathMapper.Game.Palette
  alias PathMapper.Game.State.Surface
  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Geometry.Object, as: GeometryObject
  alias PathMapper.Session.Resolve
  alias PathMapperWeb.Scene.GridComponent
  alias PathMapperWeb.Scene.MapComponent
  alias PathMapperWeb.Scene.SceneState

  @impl true
  def update(assigns, socket) do
    scene_changed = surface_was_updated?(socket, assigns)
    zoom_changed = zoom_or_pan_changed?(socket, assigns)
    socket = socket |> assign(assigns) |> close_stale_menu(scene_changed)

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

  # An open menu holds the index of the object it was opened on, and an index is
  # all a map object has - re-uploading a map or switching surface can put a
  # different object there. The menu would then name the wrong map, open the
  # wrong url, and act on the wrong thing. It cannot be re-aimed, so it closes.
  defp close_stale_menu(socket, false), do: socket
  defp close_stale_menu(socket, true), do: assign(socket, :object_context_menu, nil)

  defp has_viewport_geometry?(socket) do
    Map.has_key?(socket.assigns, :viewport_geometry)
  end

  # Guard: reject all object events in player view
  def handle_event("object_" <> _, _, %{assigns: %{opts: opts}} = socket)
      when not is_map_key(opts, :manage_objects) do
    {:noreply, socket}
  end

  # Ambient navigation (Hooks.Geometry on #scene). Available under every
  # tool for zoom, and outside any tool for pan.
  #
  # The hook fires immediately on mount, so a wheel event can arrive before
  # the viewport round-trip has reported a size to anchor against.
  @impl true
  def handle_event("map_zoom", _params, %{assigns: assigns} = socket)
      when not is_map_key(assigns, :viewport_geometry) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("map_zoom", params, socket) do
    %{
      "delta_y" => delta_y,
      "delta_mode" => delta_mode,
      "ctrl_key" => ctrl_key,
      "cx" => cx,
      "cy" => cy
    } = params

    viewport = socket.assigns.viewport_geometry

    # Recomputed rather than read off map_geometry: these are the zoom- and
    # pan-independent inputs, so they stay valid even for wheel events queued
    # behind a zoom that has not been applied yet. SceneState derives the
    # current origin from its own authoritative zoom/pan.
    base =
      socket.assigns
      |> get_map()
      |> GeometryObject.build()
      |> GeometryMapper.fit_to_viewport(viewport)

    anchor = {cx, cy, base.width, base.height, viewport.width, viewport.height}
    exponent = SceneState.wheel_exponent(delta_y, delta_mode, ctrl_key)
    send(self(), %{session_event: {:map_zoom, exponent, anchor}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("map_pan", %{"dx" => dx, "dy" => dy}, socket) do
    send(self(), %{session_event: {:map_pan, {dx, dy}}})
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
    target =
      socket.assigns.game_state
      |> declared_objects()
      |> Enum.at(index)
      |> link_target(socket.assigns.opts)

    {:noreply, assign(socket, object_context_menu: %{index: index, x: x, y: y, target: target})}
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
  def handle_event("object_follow_link", %{"index" => index_str}, socket) do
    with_parsed_index(index_str, fn index ->
      case Enum.at(declared_objects(socket.assigns.game_state), index) do
        %{link: %{target: target}} -> Game.run_action([:surface, :select], target)
        _ -> :ok
      end
    end)

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

      assigns[:opts][:my_character_id] ->
        Palette.resolve(assigns[:opts][:my_character_id]) || "#808080"

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

  # The map the geometry is fitted to has to be the map being drawn, so both ask
  # the same function. This used to decide for itself with a `custom` check, which
  # stopped meaning anything once every scene became an entity - and a scene with a
  # map uploaded onto it was then measured against the one its blob declares.
  #
  # A scene declared with no map yet falls back to the blank map state gave it.
  defp get_map(assigns) do
    scene = assigns.game_state.surface

    Surface.displayed_map(scene) || scene.map
  end

  # Geometry is derived from the map's dimensions, so it is stale exactly when
  # those change - whether because another surface was selected, or because its
  # map was re-declared. Comparing the dimensions catches both; comparing the
  # surface's identity catches only the first.
  #
  # This has now silently stopped matching twice: first on `scene.index` when
  # that field was removed, then on `game_state.scene` when the key became
  # `surface`. A map pattern against a key that no longer exists simply fails,
  # the clause stops matching, and every switch quietly keeps the previous
  # scaling. So the shape is read through a function that answers nil for
  # anything it does not recognise, and the pattern that could rot lives in one
  # place instead of two.
  defp surface_was_updated?(%{assigns: old}, new_assigns) do
    shape_of(old) != shape_of(new_assigns)
  end

  defp shape_of(%{game_state: %{surface: %{} = surface}}) do
    map = Surface.displayed_map(surface) || surface.map

    {surface.id, map && map.width, map && map.height}
  end

  defp shape_of(_assigns), do: nil

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
    origin = SceneState.rendered_origin(pan, Map.get(geo, size_key), viewport_size)
    Map.put(geo, pos_key, round(origin))
  end

  defp visible_tokens(game_state, opts) do
    tokens_with_index = Enum.with_index(game_state.surface.tokens)

    cond do
      opts[:show_hidden] ->
        tokens_with_index

      opts[:my_character_id] ->
        Enum.filter(tokens_with_index, fn {token, _index} ->
          token.state !== "hidden" or token.owner == opts[:my_character_id]
        end)

      true ->
        Enum.filter(tokens_with_index, fn {token, _index} -> token.state !== "hidden" end)
    end
  end

  @doc """
  Which grid to draw, if any.

  A map may paint its own grid on a `[G]` layer, and where it has, that image
  *is* the grid - it is what the author drew and what `docs/maps.md` promises.
  The generated one is for a map that supplied none.

  Visibility is a separate question from source: `grid-hide` on the map turns
  the grid off, and the game master's override turns it back on for their own
  view, whichever of the two sources would be drawn.
  """
  def grid_source(game_state, scene) do
    cond do
      not grid_visible?(game_state, scene) ->
        :none

      layer = MapComponent.additional_map_layer(game_state, :grid, scene.grid_override) ->
        {:painted, layer}

      true ->
        :generated
    end
  end

  defp grid_visible?(game_state, scene) do
    game_state.surface.map.show_grid or scene.grid_override
  end

  @doc false
  # The map's own objects, which is where a link lives. State carries where an
  # object has been dragged to; the declaration carries what it is.
  def declared_objects(game_state) do
    case Surface.displayed_map(game_state.surface) do
      %{map_objects: objects} when is_list(objects) -> objects
      _ -> []
    end
  end

  # The map a link names, read from the store as the menu opens. A link naming
  # nothing resolves to nothing, which is the whole of the dead-link behaviour:
  # the menu offers no way through and says nothing about why.
  defp link_target(object, opts) do
    case drawn_link(object, opts) do
      %{target: target} -> Resolve.surface(target)
      _ -> nil
    end
  end

  # A link the rendering is willing to draw. A `gm` link is drawn for whoever
  # manages objects and for nobody else, so a player sees the object as scenery.
  def drawn_link(%{link: %{gm: true} = link}, opts), do: opts[:manage_objects] && link
  def drawn_link(%{link: %{} = link}, _opts), do: link
  def drawn_link(_object, _opts), do: nil

  defp visible_objects(game_state, opts) do
    adventure_map = Surface.displayed_map(game_state.surface)

    adventure_objects = if adventure_map, do: adventure_map.map_objects || [], else: []

    state_layers = game_state.surface.map.layers

    game_state.surface.map.map_objects
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

  # A map object sits on a layer and is lit by it. The layer's image already takes
  # its lighting from a CSS class; objects were taking only its visibility, so a
  # dimmed layer dimmed its floor and left the furniture on it bright.
  defp object_light_class(%{highlight: true}), do: "highlight"
  defp object_light_class(%{light: "dim"}), do: "dimmed"
  defp object_light_class(_layer_state), do: ""

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
