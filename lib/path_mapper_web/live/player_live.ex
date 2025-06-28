defmodule PathMapperWeb.PlayerLive do
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups
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
      |> assign(:adventure, adventure)
      |> assign(:group, group)
      |> assign(:game_state, game_state)
      |> assign(:scene_state, %SceneState{})

    {:ok, socket}
  end

  @impl true
  def handle_info(%{game_update: game_state}, socket) do
    {:noreply, assign(socket, :game_state, game_state)}
  end

  @impl true
  def handle_info(%{scene_update: scene_update}, socket) do
    {:noreply,
     assign(socket, :scene_state, SceneState.run_event(socket.assigns.scene_state, scene_update))}
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
