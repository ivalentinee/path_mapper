defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState
  import PathMapperWeb.MasterLive.UIState, only: [keystroke?: 1]

  def handle_event("go_to_add_tokens", _, socket) do
    send(self(), %{ui_update: %{left_panel_select: ["left-panel", "tokens", "add-token"]}})
    {:noreply, socket}
  end

  def handle_event("go_to_add_player_tokens", _, socket) do
    send(self(), %{ui_update: %{left_panel_select: ["left-panel", "tokens", "add-player-token"]}})
    {:noreply, socket}
  end

  def handle_event("go_to_extra_tokens", _, socket) do
    send(self(), %{ui_update: %{left_panel_select: ["left-panel", "tokens", "add-extra-token"]}})
    {:noreply, socket}
  end

  def highlight_content_class(keystroke?(["left-panel", "tokens"])),
    do: "highlight highlight-items"

  def highlight_content_class(keystroke?(["left-panel", "tokens" | _rest])),
    do: "highlight"

  def highlight_content_class(_),
    do: ""

  def highlight_content_class(keystroke?(["left-panel", "tokens" | [index]]), item_index)
      when is_number(index) and index - 1 == item_index,
      do: "highlight"

  def highlight_content_class(_, _item_index), do: ""

  def selected_panel(ui_state) do
    case ui_state do
      %{left_panel: ["left-panel", "tokens", tokens_subpanel | _rest]} -> tokens_subpanel
      _ -> nil
    end
  end
end
