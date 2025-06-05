defmodule PathMapperWeb.MasterLive.UIState.Keystrokes do
  alias PathMapperWeb.MasterLive.UIState.Actions

  def run_keystroke(%{keystroke: ["p"]} = ui_state),
    do: keystroke_highlight(ui_state, :left_panel)

  def run_keystroke(%{keystroke: ["p", "s"]} = ui_state),
    do:
      ui_state
      |> Actions.select_left_panel("scene-selector")
      |> keystroke_highlight(:scene_selector)

  def run_keystroke(%{keystroke: ["p", "s", index]} = ui_state),
    do: ui_state |> Actions.select_scene_selector_item(index) |> reset_keystroke()

  def run_keystroke(%{keystroke: ["p", "q"]} = ui_state),
    do: ui_state |> Actions.select_left_panel(nil) |> reset_keystroke()

  def run_keystroke(ui_state), do: reset_keystroke(ui_state)

  def keystroke_highlight(ui_state, element) when is_atom(element) do
    Map.put(ui_state, :keystroke_highlight, element)
  end

  def set_keystroke(ui_state, keystroke) when is_list(keystroke) do
    Map.put(ui_state, :keystroke, keystroke)
  end

  def reset_keystroke(ui_state) do
    ui_state
    |> Map.put(:keystroke, [])
    |> Map.put(:keystroke_highlight, nil)
  end
end
