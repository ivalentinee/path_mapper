defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Manage do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  def handle_event("delete_token", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:tokens, :delete], &1))
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
end
