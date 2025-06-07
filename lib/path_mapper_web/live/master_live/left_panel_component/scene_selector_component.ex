defmodule PathMapperWeb.MasterLive.LeftPanelComponent.SceneSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game

  def handle_event("select_scene", %{"index" => index_string}, socket) do
    case Integer.parse(index_string) do
      {index, _rest} ->
        Game.run_action(:select_scene, index)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end

  end

  def highlight_content_class(%{keystroke_highlight: "scene-selector"}), do: "highlight"
  def highlight_content_class(_), do: ""

  def select_button_extra_classes(scene_index, selected_scene) do
    if selected_scene && selected_scene.index == scene_index, do: "selected", else: ""
  end
end
