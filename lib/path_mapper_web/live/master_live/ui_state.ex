defmodule PathMapperWeb.MasterLive.UIState do
  alias PathMapperWeb.MasterLive.UIState.Actions
  alias PathMapperWeb.MasterLive.UIState.Keystrokes

  defstruct left_panel: nil, right_panel: nil, keystroke: [], keystroke_highlight: nil

  def run_event(ui_state, %{left_panel_select: panel_name}) do
    ui_state
    |> Actions.toggle_left_panel(panel_name)
    |> Keystrokes.reset_keystroke()
  end

  def run_event(ui_state, _unknown_event) do
    Keystrokes.reset_keystroke(ui_state)
  end

  def run_key(ui_state, key) do
    ui_state
    |> Keystrokes.set_keystroke(ui_state.keystroke ++ [key])
    |> Keystrokes.run_keystroke()
  end
end
