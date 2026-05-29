defmodule PathMapperWeb.MasterLive do
  require Logger
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapperWeb.Scene.ContextMenuHelper
  alias PathMapperWeb.SessionState
  alias PathMapperWeb.SessionState.Feedback
  alias PathMapperWeb.SessionState.LeftPanel
  alias PathMapperWeb.SessionState.RightPanel
  alias PathMapperWeb.SessionState.Scene

  @plugins [LeftPanel, RightPanel, Scene, Feedback]

  @impl true
  def mount(_params, _session, socket) do
    adventures = Adventures.get()
    adventure = get_selected_adventure()
    groups = Groups.get()
    group = get_selected_group()
    game_state = Game.get_state()
    Adventures.subscribe()
    Groups.subscribe()
    Game.subscribe()

    session_state = SessionState.new(@plugins)

    socket =
      socket
      |> assign(:page_title, gettext("GM"))
      |> assign(:adventures, adventures)
      |> assign(:adventure, adventure)
      |> assign(:groups, groups)
      |> assign(:group, group)
      |> assign(:game_state, game_state)
      |> assign(:session_state, session_state)
      |> SessionState.assign_partitions(session_state)

    {:ok, socket}
  end

  def selected_layer_index(%{hovered_layer: index})
      when is_number(index),
      do: index

  def selected_layer_index(%{left_panel: ["left-panel", "map-manager", index]})
      when is_number(index),
      do: index

  def selected_layer_index(_), do: nil

  def selected_token_index(%{left_panel: ["left-panel", "tokens"]}),
    do: :all

  def selected_token_index(%{left_panel: ["left-panel", "tokens", index]})
      when is_number(index),
      do: index - 1

  def selected_token_index(_), do: nil

  @impl true
  def handle_event("navigate", %{"key" => key}, socket) do
    if key == "Escape", do: send(self(), %{session_event: %{left_panel_select: []}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_panel", _, socket) do
    send(self(), %{session_event: :close_all_panels})
    {:noreply, socket}
  end

  @impl true
  def handle_event("dismiss_load_errors", _, socket) do
    send(self(), %{session_event: :dismiss_load_errors})
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_scene_selector", _, socket) do
    send(self(), %{session_event: %{left_panel_select: ["left-panel", "scene-selector"]}})
    {:noreply, socket}
  end

  # Domain state broadcasts
  @impl true
  def handle_info(%{adventure_loaded: adventure}, socket) do
    {:noreply, assign(socket, :adventure, adventure)}
  end

  @impl true
  def handle_info(%{group_loaded: group}, socket) do
    {:noreply, assign(socket, :group, group)}
  end

  @impl true
  def handle_info(%{adventure_load_error: errors}, socket) do
    {:noreply, SessionState.apply_event(socket, {:load_error, errors})}
  end

  @impl true
  def handle_info(%{group_load_error: errors}, socket) do
    {:noreply, SessionState.apply_event(socket, {:load_error, errors})}
  end

  @impl true
  def handle_info(%{adventures_list_updated: adventures}, socket) do
    {:noreply, assign(socket, :adventures, adventures)}
  end

  @impl true
  def handle_info(%{groups_list_updated: groups}, socket) do
    {:noreply, assign(socket, :groups, groups)}
  end

  @impl true
  def handle_info(%{game_update: game_state}, socket) do
    {:noreply, assign(socket, :game_state, game_state)}
  end

  # Unified session event dispatch
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
