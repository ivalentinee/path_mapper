defmodule PathMapperWeb.PlayerLive do
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapperWeb.Scene.ContextMenuHelper
  alias PathMapperWeb.Scene.RightPanelState
  alias PathMapperWeb.Scene.SceneState

  @impl true
  def mount(_params, _session, socket) do
    adventure = get_selected_adventure()
    group = get_selected_group()
    game_state = Game.get_state()
    Adventures.subscribe()
    Groups.subscribe()
    Game.subscribe()

    socket =
      socket
      |> assign(:page_title, gettext("Player"))
      |> assign(:adventure, adventure)
      |> assign(:group, group)
      |> assign(:game_state, game_state)
      |> assign(:scene_state, %SceneState{})
      |> assign(:right_panel_state, %RightPanelState{})
      |> assign(:my_player, nil)
      |> assign(:my_token_on_map, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("close_panel", _, socket) do
    send(self(), %{right_panel_update: :close})
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{adventure_loaded: adventure}, socket) do
    {:noreply, assign(socket, :adventure, adventure)}
  end

  @impl true
  def handle_info(%{group_loaded: group}, socket) do
    my_player = refresh_my_player(socket.assigns.my_player, group)

    {:noreply,
     socket
     |> assign(:group, group)
     |> assign(:my_player, my_player)
     |> assign(:my_token_on_map, compute_my_token_on_map(socket.assigns.game_state, my_player))}
  end

  @impl true
  def handle_info(%{game_update: game_state}, socket) do
    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> assign(:my_token_on_map, compute_my_token_on_map(game_state, socket.assigns.my_player))}
  end

  @impl true
  def handle_info(%{player_update: {:claim_character, character_name}}, socket) do
    my_player = find_player(socket.assigns.group, character_name)

    {:noreply,
     socket
     |> assign(:my_player, my_player)
     |> assign(:my_token_on_map, compute_my_token_on_map(socket.assigns.game_state, my_player))}
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
    tokens = get_in(socket.assigns, [:game_state, :scene, :tokens]) || []
    ContextMenuHelper.close_other_context_menus(tokens, except_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{adventure_load_error: _}, socket), do: {:noreply, socket}

  @impl true
  def handle_info(%{group_load_error: _}, socket), do: {:noreply, socket}

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

  defp find_player(nil, _name), do: nil

  defp find_player(group, name) do
    Enum.find(group.players, &(&1.character_name == name))
  end

  defp refresh_my_player(nil, _group), do: nil

  defp refresh_my_player(%{character_name: name}, group) do
    Enum.find(group.players, &(&1.character_name == name))
  end

  defp compute_my_token_on_map(%{scene: %{tokens: tokens}}, %{character_name: name}) do
    Enum.any?(tokens, &(&1.data.name == name))
  end

  defp compute_my_token_on_map(_, _), do: false
end
