defmodule PathMapperWeb.MasterLive.LeftPanelComponent.SceneSelectorComponent do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.UIState

  alias PathMapper.Game

  def handle_event("select_scene", %{"index" => index_string}, socket) do
    with_parsed_index(index_string, &Game.run_action([:scene, :select], &1))
    {:noreply, socket}
  end

  def handle_event("unset_scene", _, socket) do
    Game.run_action([:scene, :unset], nil)
    {:noreply, socket}
  end

  def handle_event("reset_scene", _, socket) do
    Game.run_action([:scene, :reset], nil)
    {:noreply, socket}
  end

  def select_button_extra_classes(scene_index, selected_scene) do
    if selected_scene && selected_scene.index == scene_index, do: "selected", else: ""
  end
end
