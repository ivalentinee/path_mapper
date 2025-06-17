defmodule PathMapperWeb.MasterLive.LeftPanelComponent do
  use PathMapperWeb, :live_component

  alias PathMapperWeb.MasterLive.UIState

  @impl true
  def handle_event("select_panel", %{"name" => name}, socket) do
    send(self(), %{ui_update: %{left_panel_select: name}})
    {:noreply, socket}
  end

  def panel_select_button(assigns) do
    button_classes =
      if assigns[:disable_highlight],
        do: "left-panel-button pure-button",
        else: "left-panel-button pure-button enable-highlight"

    assigns = Map.put(assigns, :button_classes, button_classes)

    ~H"""
    <button
      id={"#{assigns.panel_name}-button"}
      class={@button_classes}
      phx-click="select_panel"
      phx-target={@myself}
      phx-value-name={assigns.panel_name}
    >
      {assigns.text}
    </button>
    """
  end

  def highlight_class(ui_state) do
    if ui_state.keystroke_highlight == ["left-panel"] do
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
