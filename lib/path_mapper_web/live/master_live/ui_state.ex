defmodule PathMapperWeb.MasterLive.UIState do
  defstruct left_panel: nil, right_panel: nil, keystroke: [], keystroke_highlight: nil

  def run_event(ui_state, %{left_panel_select: panel_name}) do
    ui_state
    |> select_left_panel(panel_name)
    |> reset_keystroke()
  end

  def run_event(ui_state, _unknown_event) do
    reset_keystroke(ui_state)
  end

  def run_key(ui_state, key) do
    ui_state
    |> set_keystroke(ui_state.keystroke ++ [key])
    |> run_keystroke()
  end

  defp select_left_panel(ui_state, panel_name) do
    if ui_state.left_panel == panel_name do
      Map.put(ui_state, :left_panel, nil)
    else
      Map.put(ui_state, :left_panel, panel_name)
    end
  end

  defp keystroke_highlight(ui_state, element) when is_atom(element) do
    Map.put(ui_state, :keystroke_highlight, element)
  end

  defp run_keystroke(%{keystroke: ["p"]} = ui_state),
    do: keystroke_highlight(ui_state, :left_panel)
  defp run_keystroke(%{keystroke: ["p", "a"]} = ui_state),
    do: ui_state |> select_left_panel("adventure-selector") |> reset_keystroke()

  defp run_keystroke(%{keystroke: ["p", "q"]} = ui_state),
    do: ui_state |> select_left_panel(nil) |> reset_keystroke()

  defp run_keystroke(ui_state),
    do: reset_keystroke(ui_state)

  defp set_keystroke(ui_state, keystroke) when is_list(keystroke) do
    Map.put(ui_state, :keystroke, keystroke)
  end

  defp reset_keystroke(ui_state) do
    ui_state
    |> Map.put(:keystroke, [])
    |> Map.put(:keystroke_highlight, nil)
  end
end
