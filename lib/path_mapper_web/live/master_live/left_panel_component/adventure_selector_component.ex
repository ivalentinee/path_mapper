defmodule PathMapperWeb.MasterLive.LeftPanelComponent.AdventureSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  @impl true
  def handle_event("start_empty", _, socket) do
    Game.reset_empty()
    {:noreply, socket}
  end

  @impl true
  def handle_event("restore_failed", %{"error" => error}, socket) do
    {:noreply, put_flash(socket, :error, error)}
  end
end
