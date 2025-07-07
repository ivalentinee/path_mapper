defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.AddExtra do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState
  import PathMapperWeb.MasterLive.UIState, only: [keystroke?: 1]

  alias PathMapper.Game

  def handle_event("select_player", %{"index" => index_string}, socket) do
    with_parsed_index(
      index_string,
      &send(self(), %{
        ui_update: %{left_panel_select: ["left-panel", "tokens", "add-extra-token", &1, "add"]}
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

  def show_add_notice?(
        keystroke?(["left-panel", "tokens", "add-extra-token", index]),
        player_index
      ),
      do: index == player_index

  def show_add_notice?(_, _player_index), do: false

  def show_tokens?(
        %{left_panel: ["left-panel", "tokens", "add-extra-token", index, "add"]},
        player_index
      ),
      do: index == player_index

  def show_tokens?(_, _player_index), do: false

  def highlight_content_class(keystroke?(["left-panel", "tokens", "add-extra-token"])),
    do: "highlight highlight-items"

  def highlight_content_class(keystroke?(["left-panel", "tokens", "add-extra-token", _index])),
    do: "highlight highlight-items"

  def highlight_content_class(
        keystroke?(["left-panel", "tokens", "add-extra-token", _index | _rest])
      ),
      do: "highlight"

  def highlight_content_class(_), do: ""

  def highlight_content_class(
        keystroke?(["left-panel", "tokens", "add-extra-token", player_index | _rest]),
        index
      )
      when player_index == index,
      do: "highlight highlight-items"

  def highlight_content_class(_, _), do: ""
end
