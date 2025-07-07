defmodule PathMapperWeb.MasterLive.UIState.Keystrokes do
  alias PathMapperWeb.MasterLive.UIState.Actions

  defmacro keystroke(keystroke_items), do: Enum.reverse(keystroke_items)

  def run_keystroke(%{keystroke: ["p"]} = ui_state),
    do: select_panel(ui_state, ["left-panel"])

  def run_keystroke(%{keystroke: keystroke(["p", "s"])} = ui_state),
    do: select_panel(ui_state, ["left-panel", "scene-selector"])

  def run_keystroke(%{keystroke: keystroke(["p", "s", index])} = ui_state) when is_number(index),
    do: ui_state |> Actions.select_scene_selector_item(index) |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "s", "u"])} = ui_state),
    do: ui_state |> Actions.unset_scene() |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "m"])} = ui_state),
    do: select_panel(ui_state, ["left-panel", "map-manager"])

  def run_keystroke(%{keystroke: keystroke(["p", "m", "g"])} = ui_state),
    do: ui_state |> Actions.map_manager_toggle_grid_show() |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "m", index])} = ui_state) when is_number(index),
    do: select_panel(ui_state, ["left-panel", "map-manager", index])

  def run_keystroke(%{keystroke: keystroke(["p", "m", index, "s"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.map_manager_toggle_layer_show(index) |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "m", index, "h"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.map_manager_toggle_layer_highlight(index) |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "m", index, "l"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.map_manager_toggle_layer_light(index) |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "t"])} = ui_state),
    do: select_panel(ui_state, ["left-panel", "tokens"])

  def run_keystroke(%{keystroke: keystroke(["p", "t", "a"])} = ui_state),
    do: select_panel(ui_state, ["left-panel", "tokens", "add-token"])

  def run_keystroke(%{keystroke: keystroke(["p", "t", "a", index])} = ui_state)
      when is_number(index),
      do:
        ui_state
        |> Actions.add_token(index)
        |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "t", "p"])} = ui_state),
    do: select_panel(ui_state, ["left-panel", "tokens", "add-player-token"])

  def run_keystroke(%{keystroke: keystroke(["p", "t", "p", index])} = ui_state)
      when is_number(index),
      do:
        ui_state
        |> Actions.add_player_token(index)
        |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "t", "p", "a"])} = ui_state),
    do:
      ui_state
      |> Actions.add_all_players()
      |> select_panel(["left-panel", "tokens"])
      |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "t", "e"])} = ui_state),
    do: select_panel(ui_state, ["left-panel", "tokens", "add-extra-token"])

  def run_keystroke(%{keystroke: keystroke(["p", "t", "e", index])} = ui_state)
      when is_number(index),
      do: select_panel(ui_state, ["left-panel", "tokens", "add-extra-token", index - 1])

  def run_keystroke(%{keystroke: keystroke(["p", "t", "e", player_index, "a"])} = ui_state)
      when is_number(player_index),
      do:
        select_panel(ui_state, [
          "left-panel",
          "tokens",
          "add-extra-token",
          player_index - 1,
          "add"
        ])

  def run_keystroke(%{keystroke: keystroke(["p", "t", "e", player_index, "a", index])} = ui_state)
      when is_number(index),
      do:
        ui_state
        |> Actions.add_player_extra_token(player_index, index)
        |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "t", index])} = ui_state)
      when is_number(index),
      do: select_panel(ui_state, ["left-panel", "tokens", index])

  def run_keystroke(%{keystroke: keystroke(["p", "t", index, "x"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.delete_token(index) |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "t", index, "r"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.set_token_state(index, "alive") |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "t", index, "k"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.set_token_state(index, "dead") |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "t", index, "u"])} = ui_state)
      when is_number(index),
      do: ui_state |> Actions.set_token_state(index, "unconscious") |> reset()

  def run_keystroke(%{keystroke: keystroke(["p", "q"])} = ui_state),
    do: ui_state |> Actions.select_left_panel(nil) |> reset()

  def run_keystroke(%{keystroke: ["q" | _rest]} = ui_state), do: reset(ui_state)

  def run_keystroke(%{left_panel: ["left-panel"]} = ui_state), do: reset(ui_state)
  def run_keystroke(ui_state), do: set_keystroke(ui_state, [])

  def set_keystroke(ui_state, keystroke) when is_list(keystroke) do
    Map.put(ui_state, :keystroke, keystroke)
  end

  def reset(ui_state) do
    ui_state
    |> Map.put(:keystroke, [])
    |> Map.put(:left_panel, nil)
  end

  defp select_panel(ui_state, panel) when is_list(panel),
    do:
      ui_state
      |> Actions.select_left_panel(panel)
end
