defmodule PathMapperWeb.MasterLive.LeftPanelComponent.AdventureSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Adventures
  alias PathMapper.Game

  def handle_event("select_adventure", %{"name" => name}, socket) do
    Game.load(name)
    {:noreply, socket}
  end

  def handle_event("reload", _, socket) do
    Adventures.reload()
    {:noreply, socket}
  end

  def select_button_extra_classes(adventure_filename, selected_adventure) do
    if selected_adventure && selected_adventure.file == adventure_filename,
      do: "selected",
      else: ""
  end
end
