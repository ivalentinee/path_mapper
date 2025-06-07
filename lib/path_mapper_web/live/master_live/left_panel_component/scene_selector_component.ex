defmodule PathMapperWeb.MasterLive.LeftPanelComponent.SceneSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  def handle_event("select_scene", %{"name" => name}, socket) do
    Game.select_scene(socket.assigns.adventure, name)
    {:noreply, socket}
  end

  def highlight_content_class(%{keystroke_highlight: :scene_selector}), do: "highlight"
  def highlight_content_class(_), do: ""

  def select_button_extra_classes(scene_name, selected_scene) do
    if scene_name == selected_scene, do: "selected", else: ""
  end
end
