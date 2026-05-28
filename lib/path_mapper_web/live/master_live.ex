defmodule PathMapperWeb.MasterLive do
  require Logger
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapperWeb.MasterLive.LeftPanelState
  alias PathMapperWeb.Scene.RightPanelState
  alias PathMapperWeb.Scene.SceneState

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

    socket =
      socket
      |> assign(:page_title, "GM")
      |> assign(:adventures, adventures)
      |> assign(:adventure, adventure)
      |> assign(:groups, groups)
      |> assign(:group, group)
      |> assign(:game_state, game_state)
      |> assign(:left_panel_state, %LeftPanelState{})
      |> assign(:scene_state, %SceneState{})
      |> assign(:right_panel_state, %RightPanelState{})

    {:ok, socket}
  end

  def selected_layer_index(%LeftPanelState{hovered_layer: index})
      when is_number(index),
      do: index

  def selected_layer_index(%LeftPanelState{left_panel: ["left-panel", "map-manager", index]})
      when is_number(index),
      do: index

  def selected_layer_index(%LeftPanelState{}), do: nil

  def selected_token_index(%LeftPanelState{left_panel: ["left-panel", "tokens"]}),
    do: :all

  def selected_token_index(%LeftPanelState{left_panel: ["left-panel", "tokens", index]})
      when is_number(index),
      do: index - 1

  def selected_token_index(%LeftPanelState{}), do: nil

  @impl true
  def handle_event("navigate", %{"key" => key}, socket) do
    if key == "Escape", do: send(self(), %{left_panel_update: %{left_panel_select: []}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_panel", _, socket) do
    send(self(), %{left_panel_update: %{left_panel_select: []}})
    send(self(), %{right_panel_update: :close})
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_scene_selector", _, socket) do
    send(self(), %{left_panel_update: %{left_panel_select: ["left-panel", "scene-selector"]}})
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{adventure_loaded: adventure}, socket) do
    {:noreply, assign(socket, :adventure, adventure)}
  end

  @impl true
  def handle_info(%{group_loaded: group}, socket) do
    {:noreply, assign(socket, :group, group)}
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

  @impl true
  def handle_info(%{left_panel_update: left_panel_update}, socket) do
    {:noreply,
     assign(
       socket,
       :left_panel_state,
       LeftPanelState.run_event(socket.assigns.left_panel_state, left_panel_update)
     )}
  end

  @impl true
  def handle_info(%{right_panel_update: event}, socket) do
    {:noreply,
     assign(
       socket,
       :right_panel_state,
       RightPanelState.run_event(socket.assigns.right_panel_state, event)
     )}
  end

  @impl true
  def handle_info(%{scene_update: scene_update}, socket) do
    {:noreply,
     assign(socket, :scene_state, SceneState.run_event(socket.assigns.scene_state, scene_update))}
  end

  @impl true
  def handle_info({:close_all_context_menus, except_id}, socket) do
    close_other_context_menus(socket, except_id)
    {:noreply, socket}
  end

  defp close_other_context_menus(
         %{assigns: %{game_state: %{scene: %{tokens: tokens}}}},
         except_id
       )
       when is_list(tokens) do
    tokens
    |> Enum.with_index()
    |> Enum.reject(fn {_token, index} -> "token-#{index}" == except_id end)
    |> Enum.each(fn {_token, index} ->
      send_update(PathMapperWeb.Scene.TokenComponent,
        id: "token-#{index}",
        close_context_menu: true
      )
    end)
  end

  defp close_other_context_menus(_socket, _except_id), do: :ok

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
