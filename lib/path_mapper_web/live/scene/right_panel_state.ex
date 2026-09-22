defmodule PathMapperWeb.Scene.RightPanelState do
  @moduledoc """
  What is open in the right rail.

  Two independent axes. The content panels - group, character, links, initiative,
  cheatsheet - are mutually exclusive with each other, being panels. `tool_group`
  says which family of tools the palette has expanded, and is its own axis: the
  palette lives inside the rail rather than beside it, so expanding a tool family
  competes with no panel for space.
  """
  defstruct tool_group: nil,
            group_panel_open: false,
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

  # The palette is a single narrow column, so only one family is open at a time -
  # and opening one is how the rest of the palette stays on screen.
  def run_event(%__MODULE__{} = state, {:toggle_tool_group, group}) do
    if state.tool_group == group,
      do: %{state | tool_group: nil},
      else: %{state | tool_group: group}
  end

  # Choosing a tool closes the family it came from: the toggle then shows what was
  # chosen, so leaving it open would only repeat what the collapsed rail says.
  def run_event(%__MODULE__{} = state, :close_tool_group) do
    %{state | tool_group: nil}
  end

  def run_event(%__MODULE__{} = state, :close) do
    struct!(state, @closed)
  end

  def run_event(%__MODULE__{} = state, _), do: state
end
