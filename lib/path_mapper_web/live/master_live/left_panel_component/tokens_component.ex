defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState

  alias PathMapper.Game.State.Scene.Token

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

  def selected_panel(ui_state) do
    case ui_state do
      %{left_panel: ["left-panel", "tokens", tokens_subpanel | _rest]} -> tokens_subpanel
      _ -> nil
    end
  end

  def serialize_tokens(%{scene: %{tokens: tokens}}) when is_list(tokens) do
    Token.to_place_records(tokens)
  end
end
