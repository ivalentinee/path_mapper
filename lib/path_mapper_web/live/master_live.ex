defmodule PathMapperWeb.MasterLive do
  require Logger
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapperWeb.MasterLive.UIState
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
      |> assign(:adventures, adventures)
      |> assign(:adventure, adventure)
      |> assign(:groups, groups)
      |> assign(:group, group)
      |> assign(:game_state, game_state)
      |> assign(:ui_state, %UIState{})
      |> assign(:scene_state, %SceneState{})

    {:ok, socket}
  end

  def selected_layer_index(%UIState{keystroke_highlight: ["map-manager", index]})
      when is_number(index),
      do: index - 1

  def selected_layer_index(%UIState{}), do: nil

  def selected_token_index(%UIState{keystroke_highlight: ["tokens"]}),
    do: :all

  def selected_token_index(%UIState{keystroke_highlight: ["tokens", index]})
      when is_number(index),
      do: index - 1

  def selected_token_index(%UIState{}), do: nil

  @impl true
  def handle_event("navigate", %{"key" => key}, socket) do
    {:noreply, assign(socket, :ui_state, UIState.run_key(socket.assigns.ui_state, key))}
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
  def handle_info(%{game_update: game_state}, socket) do
    {:noreply, assign(socket, :game_state, game_state)}
  end

  @impl true
  def handle_info(%{ui_update: ui_update}, socket) do
    {:noreply, assign(socket, :ui_state, UIState.run_event(socket.assigns.ui_state, ui_update))}
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
