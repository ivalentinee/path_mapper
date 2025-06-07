defmodule PathMapperWeb.MasterLive.UIState.Actions do
  alias PathMapper.Game

  def select_left_panel(ui_state, panel_name) when is_binary(panel_name) or is_nil(panel_name) do
    Map.put(ui_state, :left_panel, panel_name)
  end

  def toggle_left_panel(ui_state, panel_name) when is_binary(panel_name) or is_nil(panel_name) do
    if ui_state.left_panel == panel_name do
      Map.put(ui_state, :left_panel, nil)
    else
      Map.put(ui_state, :left_panel, panel_name)
    end
  end

  def select_scene_selector_item(%{left_panel: "scene-selector"} = ui_state, index)
      when is_number(index) do
    Game.run_action(:select_scene, index - 1)
    ui_state
  end

  def select_scene_selector_item(ui_state, _index_string), do: ui_state

  def map_manager_toggle_layer_show(%{left_panel: "map-manager"} = ui_state, index)
      when is_number(index) do
    Game.run_action([:layer, :toggle_show], index - 1)
    ui_state
  end

  def map_manager_toggle_layer_light(%{left_panel: "map-manager"} = ui_state, index)
      when is_number(index) do
    Game.run_action([:layer, :toggle_light], index - 1)
    ui_state
  end

  def map_manager_toggle_layer_highlight(%{left_panel: "map-manager"} = ui_state, index)
      when is_number(index) do
    Game.run_action([:layer, :toggle_highlight], index - 1)
    ui_state
  end
end
