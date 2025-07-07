defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.AddPlayer do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState
  import PathMapperWeb.MasterLive.UIState, only: [keystroke?: 1]

  alias PathMapper.Game

  def handle_event("add_token", %{"name" => name}, socket) do
    Game.run_action([:tokens, :player, :add], name)
    send(self(), %{ui_update: %{left_panel_select: "tokens"}})
    {:noreply, socket}
  end

  def handle_event("add_all", _, socket) do
    Game.run_action([:tokens, :player, :add_all], nil)
    send(self(), %{ui_update: %{left_panel_select: "tokens"}})
    {:noreply, socket}
  end

  def highlight_content_class(keystroke?(["left-panel", "tokens", "add-player-token"])),
    do: "highlight highlight-items"

  def highlight_content_class(_), do: ""
end
