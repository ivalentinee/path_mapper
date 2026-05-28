defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.AddPlayer do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState

  alias PathMapper.Game

  def handle_event("add_token", %{"name" => name}, socket) do
    Game.run_action([:tokens, :player, :add], name)
    {:noreply, socket}
  end

  def handle_event("add_all", _, socket) do
    Game.run_action([:tokens, :player, :add_all], nil)
    {:noreply, socket}
  end
end
