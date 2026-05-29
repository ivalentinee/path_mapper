defmodule PathMapperWeb.SessionState.LeftPanel do
  alias PathMapperWeb.MasterLive.LeftPanelState

  def key, do: :left_panel

  def init, do: %LeftPanelState{}

  def run_event(%{left_panel_select: panel}, %{left_panel: state}) when is_list(panel) do
    if state.left_panel == panel do
      %{state | left_panel: nil, owner_selector_index: nil}
    else
      %{state | left_panel: panel, owner_selector_index: nil}
    end
  end

  def run_event(%{hover_layer: index}, %{left_panel: state}) do
    Map.put(state, :hovered_layer, index)
  end

  def run_event({:toggle_owner_selector, index}, %{left_panel: state}) when is_integer(index) do
    if state.owner_selector_index == index do
      %{state | owner_selector_index: nil}
    else
      %{state | owner_selector_index: index}
    end
  end

  def run_event(:close_owner_selector, %{left_panel: state}) do
    %{state | owner_selector_index: nil}
  end

  def run_event(:close_all_panels, %{left_panel: state}) do
    %{state | left_panel: nil, owner_selector_index: nil}
  end

  def run_event(_, %{left_panel: state}), do: state
end
