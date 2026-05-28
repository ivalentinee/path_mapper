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

  def handle_event("toggle_objects_group", %{"index" => index_string}, socket) do
    {index, _} = Integer.parse(index_string)
    open_groups = socket.assigns[:open_object_groups] || MapSet.new()

    open_groups =
      if MapSet.member?(open_groups, index),
        do: MapSet.delete(open_groups, index),
        else: MapSet.put(open_groups, index)

    {:noreply, assign(socket, :open_object_groups, open_groups)}
  end

  def handle_event("toggle_object_lock", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:map_objects, &1, :toggle_lock], nil))
    {:noreply, socket}
  end

  def handle_event("toggle_object_show", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:map_objects, &1, :toggle_show], nil))
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
    |> Enum.find(&(&1.index == layer_state.index))
  end

  def objects_for_layer(layer_index, game_state, adventure) do
    adventure_objects =
      Adventure.get_scene_map(adventure, game_state.scene.index).map_objects || []

    game_state.scene.map.map_objects
    |> Enum.filter(&(&1.layer_index == layer_index))
    |> Enum.map(fn obj_state ->
      adv_obj = Enum.at(adventure_objects, obj_state.index)
      {adv_obj, obj_state}
    end)
    |> Enum.reject(fn {adv, _} -> is_nil(adv) end)
  end

  def objects_group_open?(index, assigns) do
    open_groups = assigns[:open_object_groups] || MapSet.new()
    MapSet.member?(open_groups, index)
  end
end
