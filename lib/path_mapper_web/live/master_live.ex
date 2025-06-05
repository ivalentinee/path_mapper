defmodule PathMapperWeb.MasterLive do
  require Logger
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapper.Game
  alias PathMapperWeb.MasterLive.UIState

  @impl true
  def mount(_params, _session, socket) do
    adventures = Adventures.get()
    game = Game.get()
    Adventures.subscribe()
    Game.subscribe()

    socket =
      socket
      |> assign(:adventures, adventures)
      |> assign(:game, game)
      |> assign(:ui_state, %UIState{})

    {:ok, socket}
  end

  @impl true
  def handle_event("navigate", %{"key" => key}, socket) do
    {:noreply, assign(socket, :ui_state, UIState.run_key(socket.assigns.ui_state, key))}
  end

  @impl true
  def handle_info(%{adventure_loaded: adventures}, socket) do
    {:noreply, assign(socket, :adventures, adventures)}
  end

  @impl true
  def handle_info(%{game_update: game}, socket) do
    {:noreply, assign(socket, :game, game)}
  end

  @impl true
  def handle_info(%{ui_update: ui_update}, socket) do
    {:noreply, assign(socket, :ui_state, UIState.run_event(socket.assigns.ui_state, ui_update))}
  end
end
