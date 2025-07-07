defmodule PathMapperWeb.MasterLive.UIState.Actions do
  alias PathMapper.Game

  def select_left_panel(ui_state, panel_name) when is_list(panel_name) or is_nil(panel_name) do
    Map.put(ui_state, :left_panel, panel_name)
  end

  def toggle_left_panel(ui_state, panel_name) when is_list(panel_name) or is_nil(panel_name) do
    if ui_state.left_panel == panel_name do
      Map.put(ui_state, :left_panel, nil)
    else
      Map.put(ui_state, :left_panel, panel_name)
    end
  end

  def select_scene_selector_item(ui_state, index)
      when is_number(index) do
    Game.run_action([:scene, :select], index - 1)
    ui_state
  end

  def select_scene_selector_item(ui_state, _index_string), do: ui_state

  def unset_scene(ui_state) do
    Game.run_action([:scene, :unset], nil)
    ui_state
  end

  def unset_scene(ui_state), do: ui_state

  def map_manager_toggle_grid_show(ui_state) do
    Game.run_action([:map, :toggle_grid], nil)
    ui_state
  end

  def map_manager_toggle_layer_show(ui_state, index)
      when is_number(index) do
    Game.run_action([:map, :layer, :toggle_show], index - 1)
    ui_state
  end

  def map_manager_toggle_layer_light(ui_state, index)
      when is_number(index) do
    Game.run_action([:map, :layer, :toggle_light], index - 1)
    ui_state
  end

  def map_manager_toggle_layer_highlight(ui_state, index)
      when is_number(index) do
    Game.run_action([:map, :layer, :toggle_highlight], index - 1)
    ui_state
  end

  def add_token(ui_state, index) when is_number(index) do
    Game.run_action([:tokens, :add], index - 1)
    ui_state
  end

  def add_player_token(ui_state, index)
      when is_number(index) do
    Game.run_action([:tokens, :player, :add], index - 1)
    ui_state
  end

  def add_all_players(ui_state) do
    Game.run_action([:tokens, :player, :add_all], nil)
    ui_state
  end

  def delete_token(ui_state, index) when is_number(index) do
    Game.run_action([:tokens, :delete], index - 1)
    ui_state
  end

  def set_token_state(ui_state, index, state)
      when is_number(index) and is_binary(state) do
    Game.run_action([:tokens, index - 1, :set_state], state)
    ui_state
  end
end
