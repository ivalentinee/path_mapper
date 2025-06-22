defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent do
  use PathMapperWeb, :live_component

  def handle_event("go_to_add_tokens", _, socket) do
    send(self(), %{ui_update: %{left_panel_select: "add-token"}})
    {:noreply, socket}
  end

  def handle_event("go_to_add_player_tokens", _, socket) do
    send(self(), %{ui_update: %{left_panel_select: "add-player-token"}})
    {:noreply, socket}
  end

  def highlight_content_class(%{keystroke_highlight: ["tokens"]}),
    do: "highlight highlight-items"

  def highlight_content_class(%{keystroke_highlight: ["add-token"]}),
    do: "highlight highlight-items"

  def highlight_content_class(%{keystroke_highlight: ["add-player-token"]}),
    do: "highlight highlight-items"

  def highlight_content_class(%{keystroke_highlight: ["tokens" | _]}), do: "highlight"
  def highlight_content_class(%{keystroke_highlight: ["add-token" | _]}), do: "highlight"
  def highlight_content_class(%{keystroke_highlight: ["add-player-token" | _]}), do: "highlight"
  def highlight_content_class(_), do: ""

  def highlight_content_class(%{keystroke_highlight: ["tokens" | [index]]}, item_index)
      when is_number(index) and index - 1 == item_index,
      do: "highlight"

  def highlight_content_class(_, _item_index), do: ""
end
