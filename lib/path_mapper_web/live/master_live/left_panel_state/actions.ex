defmodule PathMapperWeb.MasterLive.LeftPanelState.Actions do
  alias PathMapper.Game

  def select_left_panel(state, panel_name) when is_list(panel_name) or is_nil(panel_name) do
    Map.put(state, :left_panel, panel_name)
  end

  def toggle_left_panel(state, panel_name) when is_list(panel_name) or is_nil(panel_name) do
    if state.left_panel == panel_name do
      Map.put(state, :left_panel, nil)
    else
      Map.put(state, :left_panel, panel_name)
    end
  end

  def select_scene_selector_item(state, index)
      when is_number(index) do
    Game.run_action([:scene, :select], index - 1)
    state
  end

  def select_scene_selector_item(state, _index_string), do: state

  def unset_scene(state) do
    Game.run_action([:scene, :unset], nil)
    state
  end

  def map_manager_toggle_grid_show(state) do
    Game.run_action([:map, :toggle_grid], nil)
    state
  end

  def map_manager_toggle_layer_show(state, index)
      when is_number(index) do
    Game.run_action([:map, :layer, :toggle_show], index - 1)
    state
  end

  def map_manager_toggle_layer_light(state, index)
      when is_number(index) do
    Game.run_action([:map, :layer, :toggle_light], index - 1)
    state
  end

  def map_manager_toggle_layer_highlight(state, index)
      when is_number(index) do
    Game.run_action([:map, :layer, :toggle_highlight], index - 1)
    state
  end

  def add_token(state, index) when is_number(index) do
    Game.run_action([:tokens, :add], index - 1)
    state
  end

  def add_player_token(state, index)
      when is_number(index) do
    Game.run_action([:tokens, :player, :add], index - 1)
    state
  end

  def add_all_players(state) do
    Game.run_action([:tokens, :player, :add_all], nil)
    state
  end

  def add_player_extra_token(state, player_index, token_index) do
    Game.run_action([:tokens, :player, :add_extra], {player_index - 1, token_index - 1})
    state
  end

  def delete_token(state, index) when is_number(index) do
    Game.run_action([:tokens, :delete], index - 1)
    state
  end

  def set_token_state(panel_state, index, token_state)
      when is_number(index) and is_binary(token_state) do
    Game.run_action([:tokens, index - 1, :set_state], token_state)
    panel_state
  end
end
