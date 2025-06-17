defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Manage do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  def handle_event("delete_token", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:tokens, :delete], &1))
    {:noreply, socket}
  end

  def handle_event("restore_token", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:tokens, &1, :set_state], "alive"))
    {:noreply, socket}
  end

  def handle_event("kill_token", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:tokens, &1, :set_state], "dead"))
    {:noreply, socket}
  end

  def handle_event("knock_out_token", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:tokens, &1, :set_state], "unconscious"))
    {:noreply, socket}
  end

  def highlight_content_class(%{keystroke_highlight: ["tokens"]}),
    do: "highlight"

  def highlight_content_class(_), do: ""

  def highlight_content_class(%{keystroke_highlight: ["tokens" | [index]]}, item_index)
      when index - 1 == item_index,
      do: "highlight"

  def highlight_content_class(%{keystroke_highlight: ["tokens" | _index]}, _item_index),
    do: ""

  def highlight_content_class(_, _item_index), do: ""

  def restore_button_text(%{keystroke_highlight: ["tokens" | [index]]}, item_index)
      when index - 1 == item_index,
      do: "R"

  def restore_button_text(_ui_state, _item_index),
    do: "💕"

  def kill_button_text(%{keystroke_highlight: ["tokens" | [index]]}, item_index)
      when index - 1 == item_index,
      do: "K"

  def kill_button_text(_ui_state, _item_index),
    do: "🗡"

  def knock_out_button_text(%{keystroke_highlight: ["tokens" | [index]]}, item_index)
      when index - 1 == item_index,
      do: "U"

  def knock_out_button_text(_ui_state, _item_index),
    do: "💤"

  def highlight_state_button_class(%{state: token_state}, state) when token_state == state,
    do: "highlight"

  def highlight_state_button_class(_token, _state), do: ""
end
