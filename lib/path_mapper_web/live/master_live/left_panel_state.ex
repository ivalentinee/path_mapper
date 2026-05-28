defmodule PathMapperWeb.MasterLive.LeftPanelState do
  alias PathMapperWeb.MasterLive.LeftPanelState.Actions

  defstruct left_panel: nil, hovered_layer: nil

  def run_event(state, %{left_panel_select: panel}) when is_list(panel) do
    Actions.toggle_left_panel(state, panel)
  end

  def run_event(state, %{hover_layer: index}) do
    Map.put(state, :hovered_layer, index)
  end

  def run_event(state, _unknown_event), do: state
end
