defmodule PathMapperWeb.MasterLive.LeftPanelComponent do
  use PathMapperWeb, :live_component

  @impl true
  def handle_event("select_panel", %{"name" => name}, socket) do
    send(self(), %{ui_update: %{left_panel_select: name}})
    {:noreply, socket}
  end

  def highlight_class(ui_state) do
    if ui_state.keystroke_highlight == :left_panel do
      "highlight"
    else
      ""
    end
  end
end
