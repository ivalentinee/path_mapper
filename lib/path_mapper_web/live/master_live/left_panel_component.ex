defmodule PathMapperWeb.MasterLive.LeftPanelComponent do
  use PathMapperWeb, :live_component

  alias PathMapperWeb.MasterLive.LeftPanelState

  @impl true
  def handle_event("select_panel", %{"name" => name}, socket) do
    send(self(), %{session_event: %{left_panel_select: ["left-panel", name]}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def panel_select_button(assigns) do
    active = selected_panel(assigns[:left_panel]) == assigns.panel_name
    classes = "left-panel-button pure-button #{if active, do: "active"}"
    assigns = Map.put(assigns, :button_classes, classes)

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

  def selected_panel(left_panel_state) do
    case left_panel_state do
      %{left_panel: ["left-panel", left_subpanel | _rest]} -> left_subpanel
      _ -> nil
    end
  end

  def select_button_extra_classes(%LeftPanelState{left_panel: selected_panel_name}, panel_name)
      when panel_name == selected_panel_name,
      do: "selected"

  def select_button_extra_classes(_left_panel_state, _panel_name), do: ""
end
