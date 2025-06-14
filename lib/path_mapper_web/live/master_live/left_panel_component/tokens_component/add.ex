defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Add do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  def handle_event("add_token", %{"name" => name}, socket) do
    Game.run_action([:tokens, :add], name)
    send(self(), %{ui_update: %{left_panel_select: "tokens"}})
    {:noreply, socket}
  end

  def highlight_content_class(%{keystroke_highlight: ["tokens-add"]}),
    do: "highlight highlight-items"

  # def highlight_content_class(%{keystroke_highlight: ["tokens" | _]}), do: "highlight"
  def highlight_content_class(_), do: ""

  # def highlight_content_class(%{keystroke_highlight: ["tokens" | [index]]}, item_index)
  #     when index - 1 == item_index,
  #     do: "highlight"

  # def highlight_content_class(%{keystroke_highlight: ["tokens" | _index]}, _item_index),
  #   do: ""

  def highlight_content_class(_, _item_index), do: ""

  # def button_extra_classes(map_name, selected_map) do
  #   if map_name == selected_map, do: "selected", else: ""
  # end

  # def adventure_layer(adventure, game_state, layer_state) do
  #   adventure
  #   |> Map.get(:scenes)
  #   |> Enum.at(game_state.scene.index)
  #   |> Map.get(:map)
  #   |> Map.get(:layers)
  #   |> Enum.at(layer_state.index)
  # end
end
