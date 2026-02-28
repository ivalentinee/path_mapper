defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Manage do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState
  require PathMapper.Game.State.Scene.Token
  import PathMapper.Game.State.Scene.Token, only: [states: 0]

  alias PathMapper.Game

  embed_templates "manage_state_button*"

  def handle_event("delete_token", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:tokens, :delete], &1))
    {:noreply, socket}
  end

  def handle_event("set_token_state", %{"index" => index_string, "state" => state}, socket)
      when state in states() do
    with_parsed_index(index_string, &Game.run_action([:tokens, &1, :set_state], state))
    {:noreply, socket}
  end

  def highlight_content_class(keystroke?(["left-panel", "tokens"])),
    do: "highlight"

  def highlight_content_class(_), do: ""

  def highlight_content_class(keystroke?(["left-panel", "tokens" | [index]]), item_index)
      when index - 1 == item_index,
      do: "highlight"

  def highlight_content_class(keystroke?(["left-panel", "tokens" | _index]), _item_index),
    do: ""

  def highlight_content_class(_, _item_index), do: ""
end
