defmodule PathMapperWeb.MasterLive.LeftPanelComponent.SceneSelectorComponent do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game

  def handle_event("select_scene", %{"id" => id}, socket) do
    Game.run_action([:scene, :select], id)
    {:noreply, clear_ui_state(socket)}
  end

  def handle_event("unset_scene", _, socket) do
    Game.run_action([:scene, :unset], nil)
    {:noreply, clear_ui_state(socket)}
  end

  def handle_event("reset_scene", _, socket) do
    if socket.assigns[:confirm_reset] do
      Game.run_action([:scene, :reset], nil)
      {:noreply, clear_ui_state(socket)}
    else
      {:noreply, socket |> clear_ui_state() |> assign(:confirm_reset, true)}
    end
  end

  def select_button_extra_classes(scene_id, selected_scene) do
    if selected_scene && selected_scene.id == scene_id, do: "selected", else: ""
  end

  defp clear_ui_state(socket) do
    socket
    |> assign(:confirm_reset, false)
  end
end
