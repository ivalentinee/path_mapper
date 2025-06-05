defmodule PathMapperWeb.MasterLive do
  require Logger
  use PathMapperWeb, :live_view

  alias PathMapper.Adventures
  alias PathMapperWeb.MasterLive.UIState

  @impl true
  def mount(_params, _session, socket) do
    adventures = Adventures.get_adventures()
    Adventures.subscribe()

    socket =
      socket
      |> assign(:adventures, adventures)
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
  def handle_info(%{ui_update: ui_update}, socket) do
    {:noreply, assign(socket, :ui_state, UIState.run_event(socket.assigns.ui_state, ui_update))}
  end
end
