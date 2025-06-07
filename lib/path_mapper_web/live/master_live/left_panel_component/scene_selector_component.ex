defmodule PathMapperWeb.MasterLive.LeftPanelComponent.SceneSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  def handle_event("select_scene", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action(:select_scene, &1))
    {:noreply, socket}
  end

  def highlight_content_class(%{keystroke_highlight: ["scene-selector"]}),
    do: "highlight highlight-items"

  def highlight_content_class(_), do: ""

  def select_button_extra_classes(scene_index, selected_scene) do
    if selected_scene && selected_scene.index == scene_index, do: "selected", else: ""
  end
end
