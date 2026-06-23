defmodule PathMapperWeb.MasterLive.LeftPanelComponent.SceneSelectorComponent do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game

  def handle_event("select_scene", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:scene, :select], &1))
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

  def handle_event("start_add_scene", _, socket) do
    {:noreply, socket |> clear_ui_state() |> assign(:adding_scene, true)}
  end

  def handle_event("dismiss_scene_ui", _, socket) do
    {:noreply, clear_ui_state(socket)}
  end

  def handle_event("create_scene", %{"name" => name}, socket) do
    case Game.run_action([:scene, :create], %{"name" => name}) do
      {:ok, _} -> {:noreply, clear_ui_state(socket)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("delete_scene", %{"index" => index_string}, socket) do
    index = String.to_integer(index_string)

    if socket.assigns[:confirm_delete_index] == index do
      Game.run_action([:scene, :delete], index)
      {:noreply, assign(socket, :confirm_delete_index, nil)}
    else
      {:noreply, socket |> clear_ui_state() |> assign(:confirm_delete_index, index)}
    end
  end

  def select_button_extra_classes(scene_index, selected_scene) do
    if selected_scene && selected_scene.index == scene_index, do: "selected", else: ""
  end

  defp clear_ui_state(socket) do
    socket
    |> assign(:confirm_reset, false)
    |> assign(:confirm_delete_index, nil)
    |> assign(:adding_scene, false)
  end
end
