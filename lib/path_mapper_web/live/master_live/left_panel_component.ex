defmodule PathMapperWeb.MasterLive.LeftPanelComponent do
  use PathMapperWeb, :live_component

  alias PathMapperWeb.MasterLive.UIState

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

  def select_button_extra_classes(%UIState{left_panel: selected_panel_name}, panel_name)
      when panel_name == selected_panel_name,
      do: "selected"

  def select_button_extra_classes(_ui_state, _panel_name), do: ""
end
