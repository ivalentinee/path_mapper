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

  def select_scene_selector_item(%{left_panel: "scene-selector"} = ui_state, index_string) do
    case Integer.parse(index_string) do
      {index, _rest} ->
        Game.select_scene(index - 1)
        ui_state

      _ ->
        ui_state
    end
  end

  def select_scene_selector_item(ui_state, _index_string), do: ui_state
end
