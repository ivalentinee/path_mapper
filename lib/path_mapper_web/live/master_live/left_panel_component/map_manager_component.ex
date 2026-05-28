defmodule PathMapperWeb.MasterLive.LeftPanelComponent.MapManagerComponent do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game

  def handle_event("toggle_grid", _, socket) do
    Game.run_action([:map, :toggle_grid], nil)
    {:noreply, socket}
  end

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

  def handle_event("hover_layer", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &send(self(), %{left_panel_update: %{hover_layer: &1}}))
    {:noreply, socket}
  end

  def handle_event("unhover_layer", _, socket) do
    send(self(), %{left_panel_update: %{hover_layer: nil}})
    {:noreply, socket}
  end

  def button_extra_classes(map_name, selected_map) do
    if map_name == selected_map, do: "selected", else: ""
  end

  def adventure_layer(adventure, game_state, layer_state) do
    adventure
    |> Adventure.get_scene_map(game_state.scene.index)
    |> Map.get(:layers)
    |> Enum.at(layer_state.index)
  end
end
