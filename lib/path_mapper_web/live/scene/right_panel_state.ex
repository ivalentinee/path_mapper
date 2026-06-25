defmodule PathMapperWeb.Scene.RightPanelState do
  defstruct group_panel_open: false,
            character_panel_open: false,
            links_panel_open: false,
            initiative_panel_open: false,
            cheatsheet_panel_open: false

  @closed %{
    group_panel_open: false,
    character_panel_open: false,
    links_panel_open: false,
    initiative_panel_open: false,
    cheatsheet_panel_open: false
  }

  def run_event(%__MODULE__{} = state, :toggle_group_panel) do
    if state.group_panel_open,
      do: %{state | group_panel_open: false},
      else: struct!(state, %{@closed | group_panel_open: true})
  end

  def run_event(%__MODULE__{} = state, :toggle_character_panel) do
    if state.character_panel_open,
      do: %{state | character_panel_open: false},
      else: struct!(state, %{@closed | character_panel_open: true})
  end

  def run_event(%__MODULE__{} = state, :toggle_links_panel) do
    if state.links_panel_open,
      do: %{state | links_panel_open: false},
      else: struct!(state, %{@closed | links_panel_open: true})
  end

  def run_event(%__MODULE__{} = state, :toggle_initiative_panel) do
    if state.initiative_panel_open,
      do: %{state | initiative_panel_open: false},
      else: struct!(state, %{@closed | initiative_panel_open: true})
  end

  def run_event(%__MODULE__{} = state, :toggle_cheatsheet_panel) do
    if state.cheatsheet_panel_open,
      do: %{state | cheatsheet_panel_open: false},
      else: struct!(state, %{@closed | cheatsheet_panel_open: true})
  end

  def run_event(%__MODULE__{} = _state, :close) do
    struct!(__MODULE__, @closed)
  end

  def run_event(%__MODULE__{} = state, _), do: state
end
