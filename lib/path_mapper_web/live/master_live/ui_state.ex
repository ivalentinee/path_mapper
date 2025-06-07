defmodule PathMapperWeb.MasterLive.UIState do
  alias PathMapperWeb.MasterLive.UIState.Actions
  alias PathMapperWeb.MasterLive.UIState.Keystrokes

  defstruct left_panel: nil, right_panel: nil, keystroke: [], keystroke_highlight: nil

  @numeric_keys ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

  def run_event(ui_state, %{left_panel_select: panel_name}) do
    ui_state
    |> Actions.toggle_left_panel(panel_name)
    |> Keystrokes.reset_keystroke()
  end

  def run_event(ui_state, _unknown_event) do
    Keystrokes.reset_keystroke(ui_state)
  end

  def run_key(%{keystroke: [last_key | rest]} = ui_state, key)
      when key in @numeric_keys and is_number(last_key) do
    ui_state
    |> Keystrokes.set_keystroke([String.to_integer("#{last_key}#{key}") | rest])
    |> Keystrokes.run_keystroke()
  end

  def run_key(ui_state, key) when key in @numeric_keys do
    ui_state
    |> Keystrokes.set_keystroke([String.to_integer(key) | ui_state.keystroke])
    |> Keystrokes.run_keystroke()
  end

  def run_key(ui_state, key) do
    ui_state
    |> Keystrokes.set_keystroke([key | ui_state.keystroke])
    |> Keystrokes.run_keystroke()
  end
end
