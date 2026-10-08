defmodule PathMapperWeb.PlayerLive do
  use PathMapperWeb, :live_view

  alias PathMapper.Game
  alias PathMapper.Session.Resolve
  alias PathMapperWeb.Scene.ContextMenuHelper
  alias PathMapperWeb.SessionState
  alias PathMapperWeb.SessionState.Character
  alias PathMapperWeb.SessionState.Language
  alias PathMapperWeb.SessionState.RightPanel
  alias PathMapperWeb.SessionState.Scene
  alias PathMapperWeb.ViewedSurface

  @plugins [RightPanel, Scene, Character, Language]

  @impl true
  def mount(params, session, socket) do
    connect_locale = get_connect_params(socket)["locale"]
    locale = session["locale"] || connect_locale || "en"
    Gettext.put_locale(PathMapperWeb.Gettext, locale)

    viewed = params["surface_id"]
    :ok = ViewedSurface.check!(viewed)
    game_state = Game.get_state(viewed)

    Game.subscribe()
    PathMapper.MapTools.subscribe()
    PathMapper.Charkeeper.subscribe()

    charkeeper = PathMapper.Charkeeper.get_data()

    session_state =
      @plugins
      |> SessionState.new()
      |> Map.put(:language, %{locale: locale})

    session_id = inspect(self())

    socket =
      socket
      |> assign(:page_title, gettext("Player"))
      |> assign(:characters, Resolve.characters())
      |> assign(:viewed_surface_id, viewed)
      |> assign(:game_state, game_state)
      |> assign(:session_state, session_state)
      |> assign(:session_id, session_id)
      |> assign(:tool_draws, PathMapper.MapTools.get_all())
      |> assign(:charkeeper_data, charkeeper.data)
      |> assign(:charkeeper_status, charkeeper.status)
      |> SessionState.assign_partitions(session_state)

    {:ok, socket}
  end

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    assigns = Map.put_new(socket.assigns, :left_panel, %{left_panel: nil})

    case PathMapperWeb.KeyboardDispatch.dispatch(key, assigns, :player) do
      nil ->
        {:noreply, socket}

      {:set_pending_prefix, prefix} ->
        scene = %{socket.assigns.scene | pending_prefix: prefix}
        {:noreply, assign(socket, :scene, scene)}

      {:arrow_pan, direction} ->
        handle_arrow_pan(socket, direction)

      event ->
        send(self(), %{session_event: event})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_panel", _, socket) do
    send(self(), %{session_event: :close_all_panels})
    {:noreply, socket}
  end

  defp handle_arrow_pan(socket, direction) do
    grid_size =
      socket.assigns.game_state[:scene] && socket.assigns.game_state.surface.map.grid_size

    if grid_size do
      {dx, dy} =
        case direction do
          :up -> {0, grid_size}
          :down -> {0, -grid_size}
          :left -> {grid_size, 0}
          :right -> {-grid_size, 0}
        end

      send(self(), %{session_event: {:map_pan, {dx, dy}}})
    end

    {:noreply, socket}
  end

  # One channel. A command, or the store gaining or losing a piece, arrives the
  # same way and carries the same payload.
  @impl true
  def handle_info(%{game_update: game_state}, socket) do
    {:noreply,
     socket
     |> assign(:game_state, ViewedSurface.rendered(game_state, socket.assigns.viewed_surface_id))
     |> assign(:characters, Resolve.characters())
     |> recompute_identity(game_state)}
  end

  # Session events (unified dispatch)
  @impl true
  def handle_info(%{session_event: {:claim_character, id}}, socket) do
    identity =
      Character.set_character(
        socket.assigns.character,
        Resolve.character(id),
        socket.assigns.game_state
      )

    session_state = Map.put(socket.assigns.session_state, :character, identity)

    {:noreply,
     socket
     |> assign(:session_state, session_state)
     |> assign(:character, identity)}
  end

  @impl true
  # A drawing is owned by the player's id, not their character name. A name is
  # free text a player chooses, and the draw actions read "GM" as authority - so
  # a character called GM could erase anyone's drawings and clear the board.
  def handle_info(%{session_event: :draw_undo}, socket) do
    owner = socket.assigns.character.mine && socket.assigns.character.mine.id

    if owner, do: Game.run_action([:draw, :undo], %{owner: owner})
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{session_event: event}, socket) do
    {:noreply, SessionState.apply_event(socket, event)}
  end

  # Charkeeper broadcasts
  @impl true
  def handle_info(%{charkeeper_update: %{data: data, status: status}}, socket) do
    {:noreply,
     socket
     |> assign(:charkeeper_data, data)
     |> assign(:charkeeper_status, status)}
  end

  # Map tool broadcasts — store remote tools only, rendered as elements in template
  @impl true
  def handle_info(%{tool_update: tool_data}, socket) do
    sid = tool_data["session_id"]

    if sid == socket.assigns.session_id do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :tool_draws, Map.put(socket.assigns.tool_draws, sid, tool_data))}
    end
  end

  @impl true
  def handle_info(%{tool_clear: session_id}, socket) do
    {:noreply, assign(socket, :tool_draws, Map.delete(socket.assigns.tool_draws, session_id))}
  end

  # Context menu coordination
  @impl true
  def handle_info(
        {:close_all_context_menus, except_id},
        %{assigns: %{game_state: %{scene: %{tokens: tokens}}}} = socket
      )
      when is_list(tokens) do
    ContextMenuHelper.close_other_context_menus(tokens, except_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:close_all_context_menus, _}, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    PathMapper.MapTools.clear(socket.assigns[:session_id])
    :ok
  end

  defp recompute_identity(socket, game_state) do
    identity = Character.recompute(socket.assigns.character, game_state)
    session_state = Map.put(socket.assigns.session_state, :character, identity)

    socket
    |> assign(:session_state, session_state)
    |> assign(:character, identity)
  end
end
