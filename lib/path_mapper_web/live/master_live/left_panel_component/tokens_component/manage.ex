defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Manage do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState
  alias PathMapperWeb.MasterLive.LeftPanelState

  require PathMapper.TokenStates
  import PathMapper.TokenStates, only: [states: 0]

  alias PathMapper.Game
  alias PathMapper.Game.Palette
  alias PathMapper.Game.State.Scene.Token, as: GameToken

  embed_templates "manage_state_button*"

  def handle_event("delete_token", %{"game-id" => game_id}, socket) do
    Game.run_action([:tokens, :delete], game_id)
    unset_selected_token(socket.assigns.left_panel)
    {:noreply, socket}
  end

  def handle_event("set_token_state", %{"game-id" => game_id, "state" => state}, socket)
      when state in states() do
    Game.run_action([:tokens, game_id, :set_state], state)
    {:noreply, socket}
  end

  def handle_event("toggle_naming", %{"game-id" => game_id}, socket) do
    send(self(), %{session_event: {:toggle_naming, game_id}})
    {:noreply, socket}
  end

  # The placeholder shows the declaration's name, so submitting an empty field
  # means "call it what the token is called" rather than "call it nothing".
  def handle_event("set_token_name", %{"game-id" => game_id, "name" => name}, socket) do
    Game.run_action([:tokens, game_id, :set_name], name)
    send(self(), %{session_event: :close_naming})
    {:noreply, socket}
  end

  def handle_event("clear_token_name", %{"game-id" => game_id}, socket) do
    Game.run_action([:tokens, game_id, :set_name], nil)
    send(self(), %{session_event: :close_naming})
    {:noreply, socket}
  end

  def handle_event("toggle_owner_selector", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, fn index ->
      send(self(), %{session_event: {:toggle_owner_selector, index}})
    end)

    {:noreply, socket}
  end

  def handle_event("set_token_owner", %{"game-id" => game_id, "owner" => owner}, socket) do
    Game.run_action([:tokens, game_id, :set_owner], owner)
    send(self(), %{session_event: :close_owner_selector})
    {:noreply, socket}
  end

  def selected_tokens(game_state, %{left_panel: ["left-panel", "tokens" | [index]]}) do
    tokens_with_index = Enum.with_index(game_state.scene.tokens)
    token = Enum.at(tokens_with_index, index - 1)
    if token, do: [token], else: tokens_with_index
  end

  def selected_tokens(game_state, _left_panel) do
    Enum.with_index(game_state.scene.tokens)
  end

  def available_owners do
    owners = Map.keys(Palette.get())
    fixed = ["enemy", "npc", "none"]
    {fixed_present, characters} = Enum.split_with(owners, &(&1 in fixed))
    Enum.filter(fixed, &(&1 in fixed_present)) ++ Enum.sort(characters)
  end

  defp unset_selected_token(%LeftPanelState{left_panel: ["left-panel", "tokens", _index]}) do
    send(self(), %{session_event: %{left_panel_select: ["left-panel", "tokens"]}})
  end

  defp unset_selected_token(%LeftPanelState{}), do: nil
end
