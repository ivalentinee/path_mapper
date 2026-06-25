defmodule PathMapperWeb.SessionState.RightPanel do
  alias PathMapperWeb.Scene.RightPanelState

  def key, do: :right_panel

  def init, do: %RightPanelState{}

  def run_event(:toggle_group_panel, %{right_panel: state}) do
    RightPanelState.run_event(state, :toggle_group_panel)
  end

  def run_event(:toggle_character_panel, %{right_panel: state}) do
    RightPanelState.run_event(state, :toggle_character_panel)
  end

  def run_event(:toggle_links_panel, %{right_panel: state}) do
    RightPanelState.run_event(state, :toggle_links_panel)
  end

  def run_event(:toggle_initiative_panel, %{right_panel: state}) do
    RightPanelState.run_event(state, :toggle_initiative_panel)
  end

  def run_event(:toggle_cheatsheet_panel, %{right_panel: state}) do
    RightPanelState.run_event(state, :toggle_cheatsheet_panel)
  end

  def run_event(:close, %{right_panel: state}) do
    RightPanelState.run_event(state, :close)
  end

  def run_event(:close_all_panels, %{right_panel: state}) do
    RightPanelState.run_event(state, :close)
  end

  def run_event(_, %{right_panel: state}), do: state
end
