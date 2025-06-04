defmodule PathMapperWeb.MasterLive.UIState do
  defstruct left_panel: nil, right_panel: nil

  def run_event(ui_state, %{left_panel_select: panel_name}) do
    ui_state
    |> select_left_panel(panel_name)
  end

  def run_event(ui_state, _unknown_event) do
    ui_state
  end

  defp select_left_panel(ui_state, panel_name) do
    if ui_state.left_panel == panel_name do
      Map.put(ui_state, :left_panel, nil)
    else
      Map.put(ui_state, :left_panel, panel_name)
    end
  end
end
