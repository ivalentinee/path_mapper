defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.AddPlayer do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game

  def handle_event("add_token", %{"id" => id}, socket) do
    Game.run_action([:tokens, :player, :add], id)
    {:noreply, socket}
  end

  def handle_event("add_all", _, socket) do
    Game.run_action([:tokens, :player, :add_all], nil)
    {:noreply, socket}
  end
end
