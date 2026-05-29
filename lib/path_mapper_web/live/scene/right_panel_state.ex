defmodule PathMapperWeb.Scene.RightPanelState do
  defstruct group_panel_open: false, character_panel_open: false, links_panel_open: false

  def run_event(%__MODULE__{} = state, :toggle_group_panel) do
    if state.group_panel_open do
      %{state | group_panel_open: false}
    else
      %{state | group_panel_open: true, character_panel_open: false, links_panel_open: false}
    end
  end

  def run_event(%__MODULE__{} = state, :toggle_character_panel) do
    if state.character_panel_open do
      %{state | character_panel_open: false}
    else
      %{state | character_panel_open: true, group_panel_open: false, links_panel_open: false}
    end
  end

  def run_event(%__MODULE__{} = state, :toggle_links_panel) do
    if state.links_panel_open do
      %{state | links_panel_open: false}
    else
      %{state | links_panel_open: true, group_panel_open: false, character_panel_open: false}
    end
  end

  def run_event(%__MODULE__{} = state, :close) do
    %{state | group_panel_open: false, character_panel_open: false, links_panel_open: false}
  end

  def run_event(%__MODULE__{} = state, _), do: state
end
