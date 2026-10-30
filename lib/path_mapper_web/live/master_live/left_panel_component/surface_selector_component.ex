defmodule PathMapperWeb.MasterLive.LeftPanelComponent.SurfaceSelectorComponent do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game

  def handle_event("select_surface", %{"id" => id}, socket) do
    Game.run_action([:surface, :select], id)
    {:noreply, clear_ui_state(socket)}
  end

  def handle_event("unset_surface", _, socket) do
    Game.run_action([:surface, :unset], nil)
    {:noreply, clear_ui_state(socket)}
  end

  def handle_event("reset_surface", _, socket) do
    if socket.assigns[:confirm_reset] do
      Game.run_action([:surface, :reset], nil)
      {:noreply, clear_ui_state(socket)}
    else
      {:noreply, socket |> clear_ui_state() |> assign(:confirm_reset, true)}
    end
  end

  def select_button_extra_classes(surface_id, selected_surface) do
    if selected_surface && selected_surface.id == surface_id, do: "selected", else: ""
  end

  defp clear_ui_state(socket) do
    socket
    |> assign(:confirm_reset, false)
  end
end
