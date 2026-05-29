defmodule PathMapperWeb.SessionState.LeftPanel do
  alias PathMapperWeb.MasterLive.LeftPanelState

  def key, do: :left_panel

  def init, do: %LeftPanelState{}

  def run_event(%{left_panel_select: panel}, %{left_panel: state}) when is_list(panel) do
    if state.left_panel == panel do
      Map.put(state, :left_panel, nil)
    else
      Map.put(state, :left_panel, panel)
    end
  end

  def run_event(%{hover_layer: index}, %{left_panel: state}) do
    Map.put(state, :hovered_layer, index)
  end

  def run_event(:close_all_panels, %{left_panel: state}) do
    Map.put(state, :left_panel, nil)
  end

  def run_event(_, %{left_panel: state}), do: state
end
