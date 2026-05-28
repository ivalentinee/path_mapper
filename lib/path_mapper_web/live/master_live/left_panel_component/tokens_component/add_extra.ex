defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.AddExtra do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game

  def handle_event("select_player", %{"index" => index_string}, socket) do
    with_parsed_index(
      index_string,
      &send(self(), %{
        left_panel_update: %{
          left_panel_select: ["left-panel", "tokens", "add-extra-token", &1, "add"]
        }
      })
    )

    {:noreply, socket}
  end

  def handle_event("add_token", %{"player" => player_name, "index" => index_string}, socket) do
    with_parsed_index(
      index_string,
      &Game.run_action([:tokens, :player, :add_extra], {player_name, &1})
    )

    {:noreply, socket}
  end

  def show_tokens?(
        %{left_panel: ["left-panel", "tokens", "add-extra-token", index, "add"]},
        player_index
      ),
      do: index == player_index

  def show_tokens?(_, _player_index), do: false
end
