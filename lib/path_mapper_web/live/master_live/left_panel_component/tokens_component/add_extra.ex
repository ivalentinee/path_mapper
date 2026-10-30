defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.AddExtra do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game
  alias PathMapper.Session.Resolve

  def handle_event("select_player", %{"index" => index_string}, socket) do
    with_parsed_index(
      index_string,
      &send(self(), %{
        session_event: %{
          left_panel_select: ["left-panel", "tokens", "add-extra-token", &1, "add"]
        }
      })
    )

    {:noreply, socket}
  end

  def handle_event("add_token", %{"player" => player_id, "index" => index_string}, socket) do
    with_parsed_index(
      index_string,
      &Game.run_action([:tokens, :character, :add_extra], {player_id, &1})
    )

    {:noreply, socket}
  end

  def show_tokens?(
        %{left_panel: ["left-panel", "tokens", "add-extra-token", index, "add"]},
        player_index
      ),
      do: index == player_index

  def show_tokens?(_, _player_index), do: false

  # The markings a character names, resolved from the store. One not uploaded
  # yet is simply not offered.
  def extras(%{extra_token_ids: ids}) when is_list(ids) do
    Enum.flat_map(ids, fn id ->
      case Resolve.declared_token(id) do
        nil -> []
        token -> [token]
      end
    end)
  end

  def extras(_character), do: []
end
