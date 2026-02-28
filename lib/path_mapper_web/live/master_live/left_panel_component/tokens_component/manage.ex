defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Manage do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState
  require PathMapper.Game.State.Scene.Token
  alias PathMapperWeb.MasterLive.UIState
  import PathMapper.Game.State.Scene.Token, only: [states: 0]

  alias PathMapper.Game

  embed_templates "manage_state_button*"

  def handle_event("delete_token", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:tokens, :delete], &1))
    unset_selected_token(socket.assigns.ui_state)
    {:noreply, socket}
  end

  def handle_event("set_token_state", %{"index" => index_string, "state" => state}, socket)
      when state in states() do
    with_parsed_index(index_string, &Game.run_action([:tokens, &1, :set_state], state))
    {:noreply, socket}
  end

  def selected_tokens(game_state, %{left_panel: ["left-panel", "tokens" | [index]]}) do
    tokens_with_index = Enum.with_index(game_state.scene.tokens)
    token = Enum.at(tokens_with_index, index - 1)
    if token, do: [token], else: tokens_with_index
  end

  def selected_tokens(game_state, _ui_state) do
    Enum.with_index(game_state.scene.tokens)
  end

  defp unset_selected_token(%UIState{left_panel: ["left-panel", "tokens", _index]}) do
    send(self(), %{ui_update: %{left_panel_select: ["left-panel", "tokens"]}})
  end

  defp unset_selected_token(%UIState{}), do: nil
end
