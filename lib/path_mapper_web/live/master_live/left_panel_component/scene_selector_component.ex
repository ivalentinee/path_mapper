defmodule PathMapperWeb.MasterLive.LeftPanelComponent.SceneSelectorComponent do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState
  import PathMapperWeb.MasterLive.UIState, only: [keystroke?: 1]

  alias PathMapper.Game

  def handle_event("select_scene", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:scene, :select], &1))
    {:noreply, socket}
  end

  def handle_event("unset_scene", _, socket) do
    Game.run_action([:scene, :unset], nil)
    {:noreply, socket}
  end

  def highlight_content_class(keystroke?(["left-panel", "scene-selector"])),
    do: "highlight highlight-items"

  def highlight_content_class(_), do: ""

  def select_button_extra_classes(scene_index, selected_scene) do
    if selected_scene && selected_scene.index == scene_index, do: "selected", else: ""
  end
end
