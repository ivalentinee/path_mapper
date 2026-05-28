defmodule PathMapperWeb.Scene.RightPanelState do
  defstruct group_panel_open: false

  def run_event(%__MODULE__{} = state, :toggle_group_panel) do
    Map.put(state, :group_panel_open, !state.group_panel_open)
  end

  def run_event(%__MODULE__{} = state, :close) do
    Map.put(state, :group_panel_open, false)
  end

  def run_event(%__MODULE__{} = state, _), do: state
end
