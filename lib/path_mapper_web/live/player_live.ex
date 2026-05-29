defmodule PathMapperWeb.PlayerLive do
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapperWeb.Scene.ContextMenuHelper
  alias PathMapperWeb.SessionState
  alias PathMapperWeb.SessionState.Character
  alias PathMapperWeb.SessionState.RightPanel
  alias PathMapperWeb.SessionState.Scene

  @plugins [RightPanel, Scene, Character]

  @impl true
  def mount(_params, _session, socket) do
    adventure = get_selected_adventure()
    group = get_selected_group()
    game_state = Game.get_state()
    Adventures.subscribe()
    Groups.subscribe()
    Game.subscribe()

    session_state = SessionState.new(@plugins)

    socket =
      socket
      |> assign(:page_title, gettext("Player"))
      |> assign(:adventure, adventure)
      |> assign(:group, group)
      |> assign(:game_state, game_state)
      |> assign(:session_state, session_state)
      |> SessionState.assign_partitions(session_state)

    {:ok, socket}
  end

  @impl true
  def handle_event("close_panel", _, socket) do
    send(self(), %{session_event: :close_all_panels})
    {:noreply, socket}
  end

  # Domain state broadcasts
  @impl true
  def handle_info(%{adventure_loaded: adventure}, socket) do
    {:noreply, assign(socket, :adventure, adventure)}
  end

  @impl true
  def handle_info(%{group_loaded: group}, socket) do
    {:noreply,
     socket
     |> assign(:group, group)
     |> recompute_identity(socket.assigns.game_state, group)}
  end

  @impl true
  def handle_info(%{game_update: game_state}, socket) do
    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> recompute_identity(game_state, socket.assigns.group)}
  end

  # Session events (unified dispatch)
  @impl true
  def handle_info(%{session_event: {:claim_character, name}}, socket) do
    group = socket.assigns.group
    my_player = find_player(group, name)

    identity =
      Character.set_player(socket.assigns.character, my_player, socket.assigns.game_state)

    session_state = Map.put(socket.assigns.session_state, :character, identity)

    {:noreply,
     socket
     |> assign(:session_state, session_state)
     |> assign(:character, identity)}
  end

  @impl true
  def handle_info(%{session_event: event}, socket) do
    {:noreply, SessionState.apply_event(socket, event)}
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
  def handle_info(%{adventure_load_error: _}, socket), do: {:noreply, socket}

  @impl true
  def handle_info(%{group_load_error: _}, socket), do: {:noreply, socket}

  defp recompute_identity(socket, game_state, group) do
    identity = Character.recompute(socket.assigns.character, game_state, group)
    session_state = Map.put(socket.assigns.session_state, :character, identity)

    socket
    |> assign(:session_state, session_state)
    |> assign(:character, identity)
  end

  defp find_player(nil, _name), do: nil

  defp find_player(group, name) do
    Enum.find(group.players, &(&1.character_name == name))
  end

  defp get_selected_adventure do
    case Adventures.get_loaded() do
      {:ok, adventure} -> adventure
      _ -> nil
    end
  end

  defp get_selected_group do
    case Groups.get_loaded() do
      {:ok, group} -> group
      _ -> nil
    end
  end
end
