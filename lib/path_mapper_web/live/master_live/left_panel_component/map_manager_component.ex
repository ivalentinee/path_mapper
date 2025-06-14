defmodule PathMapperWeb.MasterLive.LeftPanelComponent.MapManagerComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  def handle_event("toggle_layer_show", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:map, :layer, :toggle_show], &1))
    {:noreply, socket}
  end

  def handle_event("toggle_layer_light", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:map, :layer, :toggle_light], &1))
    {:noreply, socket}
  end

  def handle_event("toggle_layer_highlight", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:map, :layer, :toggle_highlight], &1))
    {:noreply, socket}
  end

  def show_button_text(_show, "highlight"), do: "S"
  def show_button_text(true, _highlight_class), do: "✓"
  def show_button_text(false, _highlight_class), do: "✕"

  def light_button_text(_light, "highlight"), do: "L"
  def light_button_text(_light, _highlight_class), do: "💡"

  def highlight_button_text(_highlight, "highlight"), do: "H"
  def highlight_button_text(true, _highlight_class), do: "☇"
  def highlight_button_text(false, _highlight_class), do: ""

  def highlight_content_class(%{keystroke_highlight: ["map-manager"]}),
    do: "highlight highlight-items"

  def highlight_content_class(%{keystroke_highlight: ["map-manager" | _]}), do: "highlight"
  def highlight_content_class(_), do: ""

  def highlight_content_class(%{keystroke_highlight: ["map-manager" | [index]]}, item_index)
      when index - 1 == item_index,
      do: "highlight"

  def highlight_content_class(%{keystroke_highlight: ["map-manager" | _index]}, _item_index),
    do: ""

  def highlight_content_class(_, _item_index), do: ""

  def button_extra_classes(map_name, selected_map) do
    if map_name == selected_map, do: "selected", else: ""
  end

  def adventure_layer(adventure, game_state, layer_state) do
    adventure
    |> Map.get(:scenes)
    |> Enum.at(game_state.scene.index)
    |> Map.get(:map)
    |> Map.get(:layers)
    |> Enum.at(layer_state.index)
  end
end
