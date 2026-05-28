defmodule PathMapperWeb.MasterLive.UIState do
  alias PathMapperWeb.MasterLive.UIState.Actions

  defstruct left_panel: nil, hovered_layer: nil

  def run_event(ui_state, %{left_panel_select: panel}) when is_list(panel) do
    Actions.toggle_left_panel(ui_state, panel)
  end

  def run_event(ui_state, %{hover_layer: index}) do
    Map.put(ui_state, :hovered_layer, index)
  end

  def run_event(ui_state, _unknown_event), do: ui_state
end
