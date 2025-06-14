defmodule PathMapperWeb.MasterLive.UIState.Keystrokes do
  alias PathMapperWeb.MasterLive.UIState.Actions

  defmacro keystroke(keystroke_items), do: Enum.reverse(keystroke_items)

  def run_keystroke(%{keystroke: ["p"]} = ui_state),
    do: keystroke_highlight(ui_state, ["left-panel"])

  def run_keystroke(%{keystroke: keystroke(["p", "s"])} = ui_state),
    do: select_panel(ui_state, "scene-selector")

  def run_keystroke(%{keystroke: keystroke(["p", "s", index])} = ui_state) when is_number(index),
    do: ui_state |> Actions.select_scene_selector_item(index) |> reset_keystroke()

  def run_keystroke(%{keystroke: keystroke(["p", "m"])} = ui_state),
    do: select_panel(ui_state, "map-manager")

  def run_keystroke(%{keystroke: keystroke(["p", "m", index])} = ui_state) when is_number(index),
    do: keystroke_highlight(ui_state, ["map-manager", index])

  def run_keystroke(%{keystroke: keystroke(["p", "m", index, "s"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.map_manager_toggle_layer_show(index) |> reset_keystroke()

  def run_keystroke(%{keystroke: keystroke(["p", "m", index, "h"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.map_manager_toggle_layer_highlight(index) |> reset_keystroke()

  def run_keystroke(%{keystroke: keystroke(["p", "m", index, "l"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.map_manager_toggle_layer_light(index) |> reset_keystroke()

  def run_keystroke(%{keystroke: keystroke(["p", "t"])} = ui_state),
    do: select_panel(ui_state, "tokens")

  def run_keystroke(%{keystroke: keystroke(["p", "t", "a"])} = ui_state),
    do: select_panel(ui_state, "tokens-add")

  def run_keystroke(%{keystroke: keystroke(["p", "t", "a", index])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.add_token(index) |> select_panel("tokens") |> reset_keystroke()

  def run_keystroke(%{keystroke: keystroke(["p", "t", index])} = ui_state)
      when is_number(index),
      do: keystroke_highlight(ui_state, ["tokens", index])

  def run_keystroke(%{keystroke: keystroke(["p", "t", index, "x"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.delete_token(index) |> reset_keystroke()

  def run_keystroke(%{keystroke: keystroke(["p", "q"])} = ui_state),
    do: ui_state |> Actions.select_left_panel(nil) |> reset_keystroke()

  def run_keystroke(ui_state), do: reset_keystroke(ui_state)

  def keystroke_highlight(ui_state, element) when is_list(element) or is_nil(element) do
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

  defp select_panel(ui_state, panel_name),
    do:
      ui_state
      |> Actions.select_left_panel(panel_name)
      |> keystroke_highlight([panel_name])
end
