defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.AddPlayer do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  def handle_event("add_token", %{"name" => name}, socket) do
    Game.run_action([:tokens, :add_player], name)
    send(self(), %{ui_update: %{left_panel_select: "tokens"}})
    {:noreply, socket}
  end

  def handle_event("add_all", _, socket) do
    Game.run_action([:tokens, :add_all_players], nil)
    send(self(), %{ui_update: %{left_panel_select: "tokens"}})
    {:noreply, socket}
  end

  def highlight_content_class(%{keystroke_highlight: [keystroke_highlight]}, id)
      when keystroke_highlight == id,
      do: "highlight highlight-items"

  def highlight_content_class(_, _), do: ""

  def highlight_content_class(_, _, _item_index), do: ""
end
