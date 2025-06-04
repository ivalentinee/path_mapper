defmodule PathMapperWeb.MasterLive.LeftPanelComponent do
  use PathMapperWeb, :live_component

  @impl true
  def handle_event("select_panel", %{"name" => name}, socket) do
    send(self(), %{ui_update: %{left_panel_select: name}})
    {:noreply, socket}
  end
end
