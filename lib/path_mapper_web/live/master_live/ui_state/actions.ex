defmodule PathMapperWeb.MasterLive.UIState.Actions do
  alias PathMapper.Adventures
  alias PathMapper.Game

  def select_left_panel(ui_state, panel_name) when is_binary(panel_name) or is_nil(panel_name) do
    if ui_state.left_panel == panel_name do
      Map.put(ui_state, :left_panel, nil)
    else
      Map.put(ui_state, :left_panel, panel_name)
    end
  end

  def select_left_panel_item(%{left_panel: "adventure-selector"} = ui_state, index_string) do
    case Integer.parse(index_string) do
      {index, _rest} ->
        Adventures.load_adventure(index - 1)
        ui_state

      _ ->
        ui_state
    end
  end

  def select_left_panel_item(%{left_panel: "scene-selector"} = ui_state, index_string) do
    case Integer.parse(index_string) do
      {index, _rest} ->
        Game.select_scene(index - 1)
        ui_state

      _ ->
        ui_state
    end
  end
end
