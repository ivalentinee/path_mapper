defmodule PathMapperWeb.MasterLive do
  require Logger
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapperWeb.MasterLive.UIState

  @impl true
  def mount(_params, _session, socket) do
    adventures = Adventures.get()
    adventure = get_selected_adventure()
    game_state = Game.get_state()
    Adventures.subscribe()
    Game.subscribe()

    socket =
      socket
      |> assign(:adventures, adventures)
      |> assign(:adventure, adventure)
      |> assign(:game_state, game_state)
      |> assign(:ui_state, %UIState{})

    {:ok, socket}
  end

  def selected_layer_index(%UIState{keystroke_highlight: ["map-manager", index]} = ui_state) when is_number(index), do: index - 1
  def selected_layer_index(%UIState{}), do: nil

  @impl true
  def handle_event("navigate", %{"key" => key}, socket) do
    {:noreply, assign(socket, :ui_state, UIState.run_key(socket.assigns.ui_state, key))}
  end

  @impl true
  def handle_info(%{adventure_loaded: adventure}, socket) do
    {:noreply, assign(socket, :adventure, adventure)}
  end

  @impl true
  def handle_info(%{game_update: game_state}, socket) do
    {:noreply, assign(socket, :game_state, game_state)}
  end

  @impl true
  def handle_info(%{ui_update: ui_update}, socket) do
    {:noreply, assign(socket, :ui_state, UIState.run_event(socket.assigns.ui_state, ui_update))}
  end

  defp get_selected_adventure do
    case Adventures.get_loaded() do
      {:ok, adventure} -> adventure
      _ -> nil
    end
  end
end
