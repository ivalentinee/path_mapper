defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Add do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game

  def handle_event("add_token", %{"name" => name}, socket) do
    Game.run_action([:tokens, :add], name)
    {:noreply, socket}
  end
end
